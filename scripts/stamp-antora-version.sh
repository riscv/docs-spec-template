#!/usr/bin/env bash
# Stamp the Antora component descriptor (antora.yml) with the current release
# version and phase so the HTML site version stays in EXACT lockstep with the
# ARC submission PDF, per the ARC Author Guide (version = the vX.Y.Z tag; the
# title-page revision line is "Version <ver>, <date>: <Display>").
#
# The PDF derives its version dynamically at build time from the git tag via
# scripts/release-info.sh. Antora, by contrast, reads a STATIC version from the
# committed antora.yml, so a release must stamp that file. This is the Antora
# analogue of scripts/update-spec-state.sh (which stamps SPEC_STATE.md).
#
# Usage: scripts/stamp-antora-version.sh [version] [date]
#   version  vX.Y.Z (default: scripts/release-info.sh version -> latest tag)
#   date     YYYY-MM-DD (default: today)
#
# Idempotent: it replaces the values of existing keys in antora.yml in place and
# leaves comments, nav, and other attributes untouched.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
antora_yml="$repo_root/antora.yml"

version="${1:-$("$here/release-info.sh" version)}"
date="${2:-$(date +%Y-%m-%d)}"

# Normalise and validate the version (vX.Y.Z) through the shared helper.
version="$("$here/release-info.sh" normalize "$version")"

phase="$("$here/release-info.sh" phase "$version")"
phase_display="$("$here/release-info.sh" display "$version")"
phase_notice="$("$here/release-info.sh" notice "$version")"

# YAML single-quote escaping (double any embedded single quote).
yq_squote() { printf "'%s'" "${1//\'/\'\'}"; }

export A_VERSION="$version"
export A_REVDATE="$date"
export A_PHASE="$phase"
export A_PHASE_DISPLAY="$(yq_squote "$phase_display")"
export A_PHASE_NOTICE="$(yq_squote "$phase_notice")"

tmp="$(mktemp)"
# Replace values by unique key. The trailing ':' in each pattern anchors the key
# so e.g. `page-phase:` never matches `page-phase-display:`.
awk '
  /^version:/                  { print "version: " ENVIRON["A_VERSION"]; next }
  /^    page-revnumber:/       { print "    page-revnumber: " ENVIRON["A_VERSION"]; next }
  /^    page-revdate:/         { print "    page-revdate: " ENVIRON["A_REVDATE"]; next }
  /^    page-phase-display:/   { print "    page-phase-display: " ENVIRON["A_PHASE_DISPLAY"]; next }
  /^    page-phase-notice:/    { print "    page-phase-notice: " ENVIRON["A_PHASE_NOTICE"]; next }
  /^    page-phase:/           { print "    page-phase: " ENVIRON["A_PHASE"]; next }
  { print }
' "$antora_yml" > "$tmp"
mv "$tmp" "$antora_yml"

echo "Stamped antora.yml: version=$version phase=$phase ($phase_display) date=$date"
