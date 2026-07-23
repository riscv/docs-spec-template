#!/usr/bin/env bash
# Switch this template's mode in place -- reversible, run either direction.
#
#   scripts/set-mode.sh <spec|doc>   (or: make set-mode MODE=doc)
#
# A mode is normally chosen once at repo creation via the committed .docmode
# file. If it was chosen in error you do NOT need to recreate the repo: this
# helper flips .docmode AND reconciles antora.yml so the two stay consistent,
# because the two modes expect a different antora.yml shape:
#   * spec mode needs the page-phase / page-phase-display / page-phase-notice
#     cover attributes (stamped from the milestone phase).
#   * doc mode has no phase, so those keys are absent.
# After reconciling it re-stamps antora.yml via stamp-antora-version.sh.
#
# It does NOT touch content files (SPEC_STATE.md, ARC_SUBMISSION.md) or git tags
# -- it prints a reminder instead. Commit the result like any other change.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
docmode_file="$repo_root/.docmode"
antora_yml="$repo_root/antora.yml"

target="${1:-}"
case "$target" in
  spec | doc) ;;
  *)
    echo "usage: scripts/set-mode.sh <spec|doc>   (or: make set-mode MODE=doc)" >&2
    exit 2
    ;;
esac

current="$(awk 'NF && $1 !~ /^#/ { print $1; exit }' "$docmode_file" 2>/dev/null || echo spec)"
echo "set-mode: $current -> $target"

# --- 1. Flip .docmode's value line, preserving the comment block below it. -----
tmp="$(mktemp)"
awk -v t="$target" '
  !done && NF && $1 !~ /^#/ { print t; done = 1; next }
  { print }
  END { if (!done) print t }
' "$docmode_file" > "$tmp"
mv "$tmp" "$docmode_file"

# --- 2. Reconcile antora.yml page-phase* keys. --------------------------------
# FRAGILE: the awk below assumes the template's 4-space antora.yml indentation
# for the page-phase* block -- the `/^    page-phase.../` anchors and the
# `RLENGTH > 4` wrapped-continuation test both hard-code that depth (matching
# stamp-antora-version.sh). If antora.yml is ever reindented (2-space, tabs),
# update those anchors here and in stamp-antora-version.sh together. The CI
# doc-mode smoke job (build-pdf.yml) round-trips this script to catch drift.
has_phase() { grep -qE '^[[:space:]]*page-phase:' "$antora_yml"; }

if [[ "$target" == "doc" ]]; then
  if has_phase; then
    echo "set-mode: removing page-phase* attributes from antora.yml"
    tmp="$(mktemp)"
    # Delete the three page-phase* key lines and any deeper-indented (wrapped)
    # continuation lines -- mirrors stamp-antora-version.sh's indent handling.
    awk '
      drop == 1 {
        if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) { drop = 0 }
        else { match($0, /^[[:space:]]*/); if (RLENGTH > 4) next; drop = 0 }
      }
      /^    page-phase(-display|-notice)?:/ { drop = 1; next }
      { print }
    ' "$antora_yml" > "$tmp"
    mv "$tmp" "$antora_yml"
  else
    echo "set-mode: antora.yml already has no page-phase* attributes"
  fi
else # spec
  if has_phase; then
    echo "set-mode: antora.yml already has page-phase* attributes"
  else
    echo "set-mode: inserting page-phase* attributes into antora.yml (after page-revdate)"
    tmp="$(mktemp)"
    # Insert placeholders after page-revdate; the stamp below fills real values.
    awk '
      { print }
      /^    page-revdate:/ {
        print "    page-phase: draft-and-development"
        print "    page-phase-display: '\''Draft'\''"
        print "    page-phase-notice: '\''Placeholder -- stamped by set-mode.'\''"
      }
    ' "$antora_yml" > "$tmp"
    mv "$tmp" "$antora_yml"
  fi
fi

# --- 3. Re-stamp antora.yml in the new mode so values are consistent. ---------
echo "set-mode: re-stamping antora.yml"
DOC_MODE="$target" "$here/stamp-antora-version.sh"

# --- 4. Remind about the non-antora bits this helper deliberately leaves alone.
echo
echo "set-mode: now in '$target' mode. Review and commit .docmode + antora.yml."
if [[ "$target" == "doc" ]]; then
  echo "  Note: SPEC_STATE.md / ARC_SUBMISSION.md are spec-only; delete them if unused."
else
  echo "  Note: ensure SPEC_STATE.md / ARC_SUBMISSION.md are present for ARC (they ship in the template)."
fi
