#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION="v0.0.0"
DEFAULT_PHASE="draft-and-development"
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

phase_display_for_phase() {
  # Title-case display label rendered on the PDF title page and in the body
  # NOTE admonition. The canonical (lowercase, hyphenated) ID stays usable for
  # filenames, scripts, and machine-readable consumers; this is the human form.
  case "$1" in
    "draft-and-development") echo "Draft and Development" ;;
    "development-complete")  echo "Development Complete"  ;;
    "stabilized")            echo "Stabilized"            ;;
    "frozen")                echo "Frozen"                ;;
    "ratification-ready")    echo "Ratification-Ready"    ;;
    "publication")           echo "Publication"           ;;
    "ratified")              echo "Ratified"              ;;
    *)                       echo "Draft"                 ;;
  esac
}

phase_for_version() {
  local v="$1"

  if ! version_valid "$v"; then
    echo "$DEFAULT_PHASE"
    return 0
  fi

  # Canonical RISC-V P&P milestone IDs. The version number encodes the
  # milestone gate; see ARC_SUBMISSION.md.
  if version_ge "$v" "v1.0.0"; then
    echo "ratified"
  elif version_ge "$v" "v0.99.1"; then
    echo "publication"
  elif version_ge "$v" "v0.99.0"; then
    echo "ratification-ready"
  elif version_ge "$v" "v0.9.0"; then
    echo "frozen"
  elif version_ge "$v" "v0.8.0"; then
    echo "stabilized"
  elif version_ge "$v" "v0.6.0"; then
    echo "development-complete"
  else
    echo "draft-and-development"
  fi
}

milestone_for_phase() {
  case "$1" in
    "development-complete")
      echo "v0.6.x development-complete"
      ;;
    "stabilized")
      echo "v0.8.x stabilized"
      ;;
    "frozen")
      echo "v0.9.x frozen"
      ;;
    "ratification-ready")
      echo "v0.99.0 ratification-ready"
      ;;
    "publication")
      echo "v0.99.x publication"
      ;;
    "ratified")
      echo "v1.0.x ratified"
      ;;
    *)
      echo "draft-and-development"
      ;;
  esac
}

phase_floor_version() {
  case "$1" in
    "draft-and-development")
      echo "v0.0.1"
      ;;
    "development-complete")
      echo "v0.6.0"
      ;;
    "stabilized")
      echo "v0.8.0"
      ;;
    "frozen")
      echo "v0.9.0"
      ;;
    "ratification-ready")
      echo "v0.99.0"
      ;;
    "publication")
      echo "v0.99.1"
      ;;
    "ratified")
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
    "draft-and-development"|"development-complete")
      echo "Assume everything is subject to change. At this stage, ideas, structures, and content are still evolving. Feedback and iteration are encouraged as nothing is final, and adjustments may be frequent."
      ;;
    "stabilized")
      echo "Changes may still occur, but they should be limited in scope. The core structure and content are mostly settled, with only refinements or necessary adjustments expected. Any modifications should be carefully considered to maintain stability."
      ;;
    "frozen")
      echo "Changes are highly unlikely. A high threshold will be applied, and modifications will only be made in response to critical issues. Any other proposed changes should be addressed through a follow-on extension."
      ;;
    "ratification-ready")
      echo "The specification is preparing for ratification. Only critical, ratification-blocking issues should be considered for change."
      ;;
    "publication")
      echo "The specification has cleared ratification-ready and is in the publication phase pending final ratification. Only publication-phase corrections are permitted."
      ;;
    "ratified")
      echo "No changes are allowed. Any necessary or desired modifications must be addressed through a follow-on extension. Ratified extensions are never revised."
      ;;
    *)
      echo "Assume everything is subject to change until a formal milestone is reached."
      ;;
  esac
}

revremark_for_phase() {
  # revremark is rendered immediately under "Version <revnumber>, <revdate>" on
  # the asciidoctor-pdf title page. Emit only the title-case milestone label so
  # the title page reads:
  #   Version v1.0.0, 2026-05-24
  #          Ratified
  # The longer policy text moves into the body NOTE admonition (notice_for_phase).
  phase_display_for_phase "$1"
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
    phase_display_for_phase "$(phase_for_version "$value")"
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
