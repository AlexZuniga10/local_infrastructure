#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORIES_DIR="${ROOT_DIR}/repositorios"
FORCE_UPDATE=0

declare -a UPDATED_REPOSITORIES=()
declare -a CURRENT_REPOSITORIES=()
declare -a SKIPPED_REPOSITORIES=()
declare -a FAILED_REPOSITORIES=()

if [ -t 1 ]; then
  BOLD=$'\033[1m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  RED=$'\033[0;31m'
  RESET=$'\033[0m'
else
  BOLD=''
  GREEN=''
  YELLOW=''
  BLUE=''
  RED=''
  RESET=''
fi

log_step() {
  printf '\n%b\n' "${BOLD}${BLUE}==> $*${RESET}"
}

log_info() {
  printf '%b\n' "${BLUE}$*${RESET}"
}

log_success() {
  printf '%b\n' "${GREEN}$*${RESET}"
}

log_warn() {
  printf '%b\n' "${YELLOW}$*${RESET}"
}

log_error() {
  printf '%b\n' "${RED}$*${RESET}" >&2
}

usage() {
  cat <<'EOF'
Usage:
  bash ./update-local.sh [--force]

Options:
  -f, --force  Reset dirty, divergent, or locally-ahead repositories to their
               configured upstream branch. This discards tracked and untracked changes.
  -h, --help   Show this help message.
EOF
}

print_list() {
  local title="$1"
  shift

  [ "$#" -gt 0 ] || return

  printf '%b\n' "${BOLD}${title}:${RESET}"
  printf ' - %s\n' "$@"
}

force_sync_repository() {
  local repository_path="$1"
  local upstream_ref="$2"

  git -C "${repository_path}" reset --hard "${upstream_ref}" &&
    git -C "${repository_path}" clean -fd
}

update_repository() {
  local repository_path="$1"
  local repository_name="${repository_path##*/}"
  local upstream_ref
  local before_ref
  local after_ref
  local status

  log_step "Updating ${repository_name}"

  if ! git -C "${repository_path}" symbolic-ref --quiet HEAD >/dev/null; then
    log_warn "Skipping ${repository_name}; it is in a detached HEAD state."
    SKIPPED_REPOSITORIES+=("${repository_name} (detached HEAD)")
    return
  fi

  if ! upstream_ref="$(git -C "${repository_path}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"; then
    log_warn "Skipping ${repository_name}; the current branch has no upstream."
    SKIPPED_REPOSITORIES+=("${repository_name} (no upstream)")
    return
  fi

  if ! git -C "${repository_path}" fetch --all --prune; then
    log_error "Failed to fetch ${repository_name}."
    FAILED_REPOSITORIES+=("${repository_name} (fetch failed)")
    return
  fi

  if ! before_ref="$(git -C "${repository_path}" rev-parse HEAD)"; then
    log_error "Failed to determine the current commit for ${repository_name}."
    FAILED_REPOSITORIES+=("${repository_name} (missing HEAD)")
    return
  fi

  status="$(git -C "${repository_path}" status --porcelain)"
  if [ -n "${status}" ]; then
    if [ "${FORCE_UPDATE}" -eq 0 ]; then
      log_warn "Skipping ${repository_name}; local changes were detected."
      SKIPPED_REPOSITORIES+=("${repository_name} (local changes)")
      return
    fi

    log_warn "Forcing ${repository_name} to match ${upstream_ref}."
    if ! force_sync_repository "${repository_path}" "${upstream_ref}"; then
      log_error "Failed to force-update ${repository_name}."
      FAILED_REPOSITORIES+=("${repository_name} (force update failed)")
      return
    fi
  elif git merge-base --is-ancestor HEAD "${upstream_ref}"; then
    if [ "${before_ref}" = "$(git -C "${repository_path}" rev-parse "${upstream_ref}")" ]; then
      log_info "${repository_name} is already up to date."
      CURRENT_REPOSITORIES+=("${repository_name}")
      return
    fi

    if ! git -C "${repository_path}" merge --ff-only "${upstream_ref}"; then
      log_error "Failed to fast-forward ${repository_name}."
      FAILED_REPOSITORIES+=("${repository_name} (fast-forward failed)")
      return
    fi
  elif git merge-base --is-ancestor "${upstream_ref}" HEAD; then
    if [ "${FORCE_UPDATE}" -eq 0 ]; then
      log_warn "Skipping ${repository_name}; local commits are ahead of ${upstream_ref}."
      SKIPPED_REPOSITORIES+=("${repository_name} (local commits ahead)")
      return
    fi

    log_warn "Forcing ${repository_name} to match ${upstream_ref}."
    if ! force_sync_repository "${repository_path}" "${upstream_ref}"; then
      log_error "Failed to force-update ${repository_name}."
      FAILED_REPOSITORIES+=("${repository_name} (force update failed)")
      return
    fi
  elif [ "${FORCE_UPDATE}" -eq 1 ]; then
    log_warn "Forcing ${repository_name} to match ${upstream_ref}."
    if ! force_sync_repository "${repository_path}" "${upstream_ref}"; then
      log_error "Failed to force-update ${repository_name}."
      FAILED_REPOSITORIES+=("${repository_name} (force update failed)")
      return
    fi
  else
    log_warn "Skipping ${repository_name}; local and upstream history diverged."
    SKIPPED_REPOSITORIES+=("${repository_name} (diverged history)")
    return
  fi

  after_ref="$(git -C "${repository_path}" rev-parse HEAD)"
  if [ "${before_ref}" = "${after_ref}" ]; then
    CURRENT_REPOSITORIES+=("${repository_name}")
    log_info "${repository_name} is already up to date."
    return
  fi

  UPDATED_REPOSITORIES+=("${repository_name}")
  log_success "Updated ${repository_name}."
}

parse_arguments() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -f|--force)
        FORCE_UPDATE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1. Run with --help for usage."
        exit 1
        ;;
    esac
  done
}

parse_arguments "$@"

bash "${ROOT_DIR}/enviroment/check-phpenv.sh"

command -v git >/dev/null 2>&1 || {
  log_error "git is required but was not found."
  exit 1
}

if [ ! -d "${REPOSITORIES_DIR}" ]; then
  log_warn "No repositories directory exists at repositorios/."
  exit 0
fi

shopt -s nullglob
repository_paths=("${REPOSITORIES_DIR}"/*)
shopt -u nullglob

for repository_path in "${repository_paths[@]}"; do
  [ -d "${repository_path}" ] || continue

  if ! git -C "${repository_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_warn "Skipping ${repository_path##*/}; it is not a Git repository."
    SKIPPED_REPOSITORIES+=("${repository_path##*/} (not a Git repository)")
    continue
  fi

  update_repository "${repository_path}"
done

if [ "${#UPDATED_REPOSITORIES[@]}" -eq 0 ] && [ "${#CURRENT_REPOSITORIES[@]}" -eq 0 ] && [ "${#SKIPPED_REPOSITORIES[@]}" -eq 0 ] && [ "${#FAILED_REPOSITORIES[@]}" -eq 0 ]; then
  log_warn "No Git repositories were found in repositorios/."
fi

printf '\n%b\n' "${BOLD}Summary:${RESET}"
print_list "Updated repositories" "${UPDATED_REPOSITORIES[@]}"
print_list "Already current" "${CURRENT_REPOSITORIES[@]}"
print_list "Skipped repositories" "${SKIPPED_REPOSITORIES[@]}"
print_list "Repositories with errors" "${FAILED_REPOSITORIES[@]}"

if [ "${#FAILED_REPOSITORIES[@]}" -gt 0 ]; then
  exit 1
fi
