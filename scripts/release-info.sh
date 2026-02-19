#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION="v0.0.0"
DEFAULT_PHASE="Draft and Development"
SPEC_STATE_URL="http://riscv.org/spec-state"
MAX_PATCH_BEFORE_MINOR_BUMP="${MAX_PATCH_BEFORE_MINOR_BUMP:-99}"

usage() {
  cat <<'USAGE'
Usage: scripts/release-info.sh [version|normalize|next|phase|phase-floor-version|display|milestone|notice|revremark|all] [value]

Outputs release metadata derived from VERSION/RELEASE_VERSION, git tags, or defaults.
USAGE
}

normalize_version() {
  local v="$1"
  v="${v##*/}"
  if [[ "$v" != v* ]]; then
    v="v${v}"
  fi
  echo "$v"
}

base_version() {
  local v="$1"
  v="${v#v}"
  v="${v%%+*}"
  v="${v%%-*}"
  echo "$v"
}

version_valid() {
  local v
  v="$(base_version "$1")"
  [[ "$v" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]
}

parse_version() {
  local v major minor patch
  v="$(base_version "$1")"
  IFS='.' read -r major minor patch <<<"$v"
  patch="${patch:-0}"
  echo "$major" "$minor" "$patch"
}

version_ge() {
  local a1 b1 c1 a2 b2 c2
  read -r a1 b1 c1 <<<"$(parse_version "$1")"
  read -r a2 b2 c2 <<<"$(parse_version "$2")"
  if (( a1 > a2 )); then
    return 0
  fi
  if (( a1 == a2 && b1 > b2 )); then
    return 0
  fi
  if (( a1 == a2 && b1 == b2 && c1 >= c2 )); then
    return 0
  fi
  return 1
}

next_version() {
  local major minor patch
  read -r major minor patch <<<"$(parse_version "$1")"

  # Progress pre-1.0 development by rolling patch to the next minor at .99.
  if (( major == 0 && minor < 99 && patch >= MAX_PATCH_BEFORE_MINOR_BUMP )); then
    minor=$((minor + 1))
    patch=0
  else
    patch=$((patch + 1))
  fi

  printf 'v%s.%s.%s\n' "$major" "$minor" "$patch"
}

get_version() {
  local v=""

  if [[ -n "${VERSION:-}" ]]; then
    v="$VERSION"
  elif [[ -n "${RELEASE_VERSION:-}" ]]; then
    v="$RELEASE_VERSION"
  elif [[ -n "${GITHUB_REF_NAME:-}" ]]; then
    if version_valid "$GITHUB_REF_NAME"; then
      v="$GITHUB_REF_NAME"
    fi
  elif [[ -n "${GITHUB_REF:-}" ]]; then
    local ref="${GITHUB_REF##*/}"
    if version_valid "$ref"; then
      v="$ref"
    fi
  fi

  if [[ -z "$v" ]] && command -v git >/dev/null 2>&1; then
    v="$(git tag --list 'v*' --sort=-version:refname | head -n1 || true)"
  fi

  if [[ -n "$v" ]] && version_valid "$v"; then
    normalize_version "$v"
    return 0
  fi

  echo "$DEFAULT_VERSION"
}

phase_for_version() {
  local v="$1"

  if ! version_valid "$v"; then
    echo "$DEFAULT_PHASE"
    return 0
  fi

  if version_ge "$v" "v1.0.0"; then
    echo "Ratified"
  elif version_ge "$v" "v0.99.0"; then
    echo "Ratification-Ready"
  elif version_ge "$v" "v0.9.0"; then
    echo "Frozen"
  elif version_ge "$v" "v0.8.0"; then
    echo "Stable"
  elif version_ge "$v" "v0.6.0"; then
    echo "Developed"
  else
    echo "Draft and Development"
  fi
}

milestone_for_phase() {
  case "$1" in
    "Developed")
      echo "v0.6.x Developed"
      ;;
    "Stable")
      echo "v0.8.x Stable"
      ;;
    "Frozen")
      echo "v0.9.x Frozen"
      ;;
    "Ratification-Ready")
      echo "v0.99.x Ratification-Ready"
      ;;
    "Ratified")
      echo "v1.0.0 Ratified"
      ;;
    *)
      echo "Draft and Development"
      ;;
  esac
}

phase_floor_version() {
  case "$1" in
    "Draft and Development")
      echo "v0.0.1"
      ;;
    "Developed")
      echo "v0.6.0"
      ;;
    "Stable")
      echo "v0.8.0"
      ;;
    "Frozen")
      echo "v0.9.0"
      ;;
    "Ratification-Ready")
      echo "v0.99.0"
      ;;
    "Ratified")
      echo "v1.0.0"
      ;;
    *)
      echo "Unknown phase '$1'" >&2
      return 2
      ;;
  esac
}

notice_for_phase() {
  case "$1" in
    "Draft and Development"|"Developed")
      echo "Assume everything is subject to change. At this stage, ideas, structures, and content are still evolving. Feedback and iteration are encouraged as nothing is final, and adjustments may be frequent."
      ;;
    "Stable")
      echo "Changes may still occur, but they should be limited in scope. The core structure and content are mostly settled, with only refinements or necessary adjustments expected. Any modifications should be carefully considered to maintain stability."
      ;;
    "Frozen")
      echo "Changes are highly unlikely. A high threshold will be applied, and modifications will only be made in response to critical issues. Any other proposed changes should be addressed through a follow-on extension."
      ;;
    "Ratification-Ready")
      echo "The specification is preparing for ratification. Only critical, ratification-blocking issues should be considered for change."
      ;;
    "Ratified")
      echo "No changes are allowed. Any necessary or desired modifications must be addressed through a follow-on extension. Ratified extensions are never revised."
      ;;
    *)
      echo "Assume everything is subject to change until a formal milestone is reached."
      ;;
  esac
}

revremark_for_phase() {
  case "$1" in
    "Draft and Development"|"Developed")
      echo "This document is under development. Expect potential changes. Visit ${SPEC_STATE_URL} for further details."
      ;;
    "Stable")
      echo "This document is in stable state. Only limited-scope changes are expected. Visit ${SPEC_STATE_URL} for further details."
      ;;
    "Frozen")
      echo "This document is in frozen state. Only critical fixes should be considered. Visit ${SPEC_STATE_URL} for further details."
      ;;
    "Ratification-Ready")
      echo "This document is ratification-ready. Changes are highly restricted pending ratification. Visit ${SPEC_STATE_URL} for further details."
      ;;
    "Ratified")
      echo "This document is ratified. No changes are allowed; use a follow-on extension for updates. Visit ${SPEC_STATE_URL} for further details."
      ;;
    *)
      echo "This document is under development. Visit ${SPEC_STATE_URL} for further details."
      ;;
  esac
}

phase_from_input() {
  local input="${1:-}"
  if [[ -z "$input" ]]; then
    phase_for_version "$(get_version)"
  elif version_valid "$input"; then
    phase_for_version "$input"
  else
    echo "$input"
  fi
}

command="${1:-all}"
value="${2:-}"

case "$command" in
  version)
    get_version
    ;;
  normalize)
    if [[ -z "$value" ]]; then
      echo "normalize requires a version value" >&2
      exit 2
    fi
    if ! version_valid "$value"; then
      echo "invalid version: $value" >&2
      exit 2
    fi
    normalize_version "$value"
    ;;
  next)
    if [[ -z "$value" ]]; then
      value="$(get_version)"
    fi
    next_version "$value"
    ;;
  phase)
    if [[ -z "$value" ]]; then
      value="$(get_version)"
    fi
    phase_for_version "$value"
    ;;
  phase-floor-version)
    if [[ -z "$value" ]]; then
      value="$(phase_for_version "$(get_version)")"
    fi
    phase_floor_version "$value"
    ;;
  display)
    if [[ -z "$value" ]]; then
      value="$(get_version)"
    fi
    phase_for_version "$value"
    ;;
  milestone)
    phase="$(phase_from_input "$value")"
    milestone_for_phase "$phase"
    ;;
  notice)
    phase="$(phase_from_input "$value")"
    notice_for_phase "$phase"
    ;;
  revremark)
    phase="$(phase_from_input "$value")"
    revremark_for_phase "$phase"
    ;;
  all|"")
    version="$(get_version)"
    phase="$(phase_for_version "$version")"
    display="$phase"
    milestone="$(milestone_for_phase "$phase")"
    notice="$(notice_for_phase "$phase")"
    revremark="$(revremark_for_phase "$phase")"
    printf 'VERSION=%s\nPHASE=%s\nPHASE_DISPLAY=%s\nMILESTONE=%s\nPHASE_NOTICE=%s\nREVMARK=%s\n' \
      "$version" "$phase" "$display" "$milestone" "$notice" "$revremark"
    ;;
  *)
    usage
    exit 2
    ;;
esac
