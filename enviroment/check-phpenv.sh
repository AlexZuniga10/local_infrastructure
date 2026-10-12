#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHP_BINARY="${ROOT_DIR}/enviroment/phpenv/versions/8.3.6/bin/php"
PHP_LIBRARY_DIR="${ROOT_DIR}/enviroment/phpenv/lib"

if [ ! -x "${PHP_BINARY}" ]; then
  printf 'Error: PHP 8.3.6 is missing. Run bash ./setup-local.sh first.\n' >&2
  exit 1
fi

actual_version="$(LD_LIBRARY_PATH="${PHP_LIBRARY_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
  "${PHP_BINARY}" -r 'echo PHP_VERSION;')"
if [ "${actual_version}" != "8.3.6" ]; then
  printf 'Error: expected PHP 8.3.6; found %s.\n' "${actual_version}" >&2
  exit 1
fi
