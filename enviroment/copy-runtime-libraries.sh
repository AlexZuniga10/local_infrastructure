#!/usr/bin/env bash
set -euo pipefail

: "${PHPENV_ROOT:?PHPENV_ROOT is required}"
: "${MISSING_LIBRARIES:?MISSING_LIBRARIES is required}"

for library in ${MISSING_LIBRARIES}; do
  library_path="$(ldconfig -p | awk -v name="${library}" '$1 == name {print $NF; exit}')"
  if [ -z "${library_path}" ]; then
    printf 'Error: cannot locate %s in the PHP build image.\n' "${library}" >&2
    exit 1
  fi
  cp -L "${library_path}" "${PHPENV_ROOT}/lib/${library}"
done
