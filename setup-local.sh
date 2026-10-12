#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORIES_DIR="${ROOT_DIR}/repositorios"
ENV_FILE="${ROOT_DIR}/.env"
ENV_EXAMPLE_FILE="${ROOT_DIR}/.env.example"

declare -a REPOSITORY_SPECS=()
declare -a DOCKER_COMMAND=(docker)
declare -a COMPOSE_FILES=(-f docker-compose.yml)
START_MYSQL=0
START_POSTGRES=0
START_REDIS=0

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

die() {
  printf '%b\n' "${RED}Error: $*${RESET}" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  bash ./setup-local.sh [--with-mysql] [--with-postgres] [--with-redis] [--repository <name>=<git-url>]...

Options:
  --with-mysql      Start the optional shared MySQL service.
  --with-postgres   Start the optional shared PostgreSQL service.
  --with-redis      Start the optional shared Redis service.
  -r, --repository  Clone a repository into repositorios/<name>.
  -h, --help        Show this help message.

On Debian or Ubuntu, missing host prerequisites are installed automatically.

Examples:
  bash ./setup-local.sh
  bash ./setup-local.sh --with-mysql
  bash ./setup-local.sh --with-mysql --with-postgres --with-redis
  bash ./setup-local.sh --repository backend=git@github.com:example/backend.git
EOF
}

run_privileged() {
  if [ "${EUID}" -eq 0 ]; then
    "$@"
    return
  fi

  command -v sudo >/dev/null 2>&1 || die "sudo is required to install or start Docker Engine."
  sudo "$@"
}

run_docker() {
  "${DOCKER_COMMAND[@]}" "$@"
}

is_debian_family() {
  [ -r /etc/os-release ] || return 1
  . /etc/os-release
  [ "${ID:-}" = "debian" ] || [ "${ID:-}" = "ubuntu" ]
}

install_base_packages() {
  is_debian_family || die "Automatic prerequisite installation supports Debian and Ubuntu only. Install Git, Docker Engine, and Docker Compose v2 manually for this distribution."

  log_step "Installing host prerequisites"
  run_privileged apt-get update
  run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates coreutils curl git gnupg
}

install_docker_engine() {
  local distribution_id
  local distribution_codename
  local architecture
  local key_file
  local source_file

  is_debian_family || die "Automatic Docker Engine installation supports Debian and Ubuntu only."
  distribution_id="${ID}"
  distribution_codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  [ -n "${distribution_codename}" ] || die "Could not determine the distribution codename."

  command -v dpkg >/dev/null 2>&1 || die "dpkg is required to install Docker Engine."
  architecture="$(dpkg --print-architecture)"
  key_file="$(mktemp)"
  source_file="$(mktemp)"

  log_step "Installing Docker Engine and Docker Compose"
  curl -fsSL "https://download.docker.com/linux/${distribution_id}/gpg" -o "${key_file}"

  run_privileged install -m 0755 -d /etc/apt/keyrings
  run_privileged gpg --dearmor --yes --output /etc/apt/keyrings/docker.gpg "${key_file}"
  run_privileged chmod a+r /etc/apt/keyrings/docker.gpg

  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/%s %s stable\n' \
    "${architecture}" "${distribution_id}" "${distribution_codename}" > "${source_file}"
  run_privileged install -m 0644 "${source_file}" /etc/apt/sources.list.d/docker.list

  rm -f "${key_file}" "${source_file}"

  run_privileged apt-get update
  run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
  hash -r
}

configure_docker_access() {
  if docker info >/dev/null 2>&1; then
    DOCKER_COMMAND=(docker)
    return 0
  fi

  if [ "${EUID}" -eq 0 ]; then
    return 1
  fi

  if ! run_privileged docker info >/dev/null 2>&1; then
    return 1
  fi

  DOCKER_COMMAND=(sudo docker)

  if ! id -nG "${USER}" | grep -qw docker; then
    run_privileged usermod -aG docker "${USER}"
    log_warn "Added ${USER} to the docker group. Open a new WSL or Linux session to use Docker without sudo."
  fi
}

start_docker_engine() {
  if configure_docker_access; then
    return
  fi

  log_step "Starting Docker Engine"

  if command -v systemctl >/dev/null 2>&1 && run_privileged systemctl enable --now docker; then
    :
  elif command -v service >/dev/null 2>&1 && run_privileged service docker start; then
    :
  else
    die "Could not start Docker Engine. Start it in this distribution, then run setup again."
  fi

  configure_docker_access || die "Docker Engine started but is not accessible. Ensure 'docker info' succeeds."
}

ensure_host_requirements() {
  local install_base=0
  local install_docker=0

  command -v git >/dev/null 2>&1 || install_base=1
  command -v od >/dev/null 2>&1 || install_base=1
  command -v tr >/dev/null 2>&1 || install_base=1

  if [ "${install_base}" -eq 1 ]; then
    install_base_packages
  fi

  if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    install_docker=1
  fi

  if [ "${install_docker}" -eq 1 ]; then
    if ! command -v curl >/dev/null 2>&1 || ! command -v gpg >/dev/null 2>&1; then
      install_base_packages
    fi

    install_docker_engine
  fi

  command -v git >/dev/null 2>&1 || die "Git is required but was not found."
  command -v od >/dev/null 2>&1 || die "od is required but was not found."
  command -v tr >/dev/null 2>&1 || die "tr is required but was not found."
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is required."

  start_docker_engine
}

generate_secret() {
  LC_ALL=C od -An -N24 -tx1 /dev/urandom | tr -d ' \n'
}

create_env_file() {
  if [ -f "${ENV_FILE}" ]; then
    log_info "Using existing .env file."
    return
  fi

  [ -f "${ENV_EXAMPLE_FILE}" ] || die ".env.example is missing."

  log_step "Creating local environment configuration"

  (
    umask 077
    cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
    {
      printf '\n# Generated by setup-local.sh. Keep this file private.\n'
      printf 'RABBITMQ_PASSWORD=%s\n' "$(generate_secret)"
      printf 'MONGODB_PASSWORD=%s\n' "$(generate_secret)"
      printf 'MONGO_EXPRESS_PASSWORD=%s\n' "$(generate_secret)"
      printf 'MINIO_ROOT_PASSWORD=%s\n' "$(generate_secret)"
    } >> "${ENV_FILE}"
    chmod 600 "${ENV_FILE}" 2>/dev/null || true
  )

  log_success "Created .env with generated local credentials."
}

ensure_optional_service_config() {
  local setting
  local default
  local changed=0

  chmod 600 "${ENV_FILE}" 2>/dev/null || true

  for setting in MYSQL_PORT MYSQL_DATABASE MYSQL_USERNAME POSTGRES_PORT POSTGRES_DATABASE POSTGRES_USERNAME REDIS_PORT; do
    if ! grep -q "^${setting}=" "${ENV_FILE}"; then
      default="$(grep -m1 "^${setting}=" "${ENV_EXAMPLE_FILE}")" || die "${setting} is missing from .env.example."
      printf '%s\n' "${default}" >> "${ENV_FILE}"
      changed=1
    fi
  done

  for setting in MYSQL_PASSWORD MYSQL_ROOT_PASSWORD POSTGRES_PASSWORD REDIS_PASSWORD; do
    if ! grep -q "^${setting}=" "${ENV_FILE}"; then
      printf '%s=%s\n' "${setting}" "$(generate_secret)" >> "${ENV_FILE}"
      changed=1
    fi
  done

  if [ "${changed}" -eq 1 ]; then
    log_success "Optional service settings are ready in .env."
  fi
}

clone_repository() {
  local specification="$1"
  local repository_name="${specification%%=*}"
  local repository_url="${specification#*=}"
  local target_dir

  if [ "${repository_name}" = "${specification}" ] || [ -z "${repository_name}" ] || [ -z "${repository_url}" ]; then
    die "Repository values must use the format <name>=<git-url>."
  fi

  if [[ ! "${repository_name}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    die "Invalid repository name: ${repository_name}"
  fi

  target_dir="${REPOSITORIES_DIR}/${repository_name}"

  if [ -e "${target_dir}" ]; then
    if git -C "${target_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      log_warn "Skipping ${repository_name}; it is already a Git repository."
      return
    fi

    die "Cannot clone ${repository_name}; ${target_dir} already exists."
  fi

  log_step "Cloning ${repository_name}"
  git clone "${repository_url}" "${target_dir}"
  log_success "Cloned ${repository_name}."
}

parse_arguments() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --with-mysql)
        START_MYSQL=1
        shift
        ;;
      --with-postgres)
        START_POSTGRES=1
        shift
        ;;
      --with-redis)
        START_REDIS=1
        shift
        ;;
      -r|--repository)
        [ "$#" -ge 2 ] || die "${1} requires <name>=<git-url>."
        REPOSITORY_SPECS+=("$2")
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1. Run with --help for usage."
        ;;
    esac
  done
}

parse_arguments "$@"
ensure_host_requirements

log_step "Preparing isolated PHP 8.3.6 runtime"
bash "${ROOT_DIR}/enviroment/setup-phpenv.sh"

mkdir -p "${REPOSITORIES_DIR}"
create_env_file
ensure_optional_service_config

for repository_specification in "${REPOSITORY_SPECS[@]}"; do
  clone_repository "${repository_specification}"
done

if [ "${START_MYSQL}" -eq 1 ]; then
  COMPOSE_FILES+=(-f docker-compose.mysql.yml)
fi
if [ "${START_POSTGRES}" -eq 1 ]; then
  COMPOSE_FILES+=(-f docker-compose.postgres.yml)
fi
if [ "${START_REDIS}" -eq 1 ]; then
  COMPOSE_FILES+=(-f docker-compose.redis.yml)
fi

log_step "Validating local infrastructure configuration"
(cd "${ROOT_DIR}" && run_docker compose --env-file "${ENV_FILE}" "${COMPOSE_FILES[@]}" config --quiet)

log_step "Starting local infrastructure"
(cd "${ROOT_DIR}" && run_docker compose --env-file "${ENV_FILE}" "${COMPOSE_FILES[@]}" up -d)

log_success "Local infrastructure is running."
log_info "Run '${DOCKER_COMMAND[*]} compose ${COMPOSE_FILES[*]} ps' to inspect service status."
