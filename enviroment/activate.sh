#!/usr/bin/env bash

if ! (return 0 2>/dev/null); then
  printf 'Source this file: source ./enviroment/activate.sh\n' >&2
  exit 1
fi

_phpenv_workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_phpenv_workspace_phpenv_root="${_phpenv_workspace_root}/enviroment/phpenv"

if ! bash "${_phpenv_workspace_root}/enviroment/check-phpenv.sh"; then
  unset _phpenv_workspace_root _phpenv_workspace_phpenv_root
  return 1
fi

if [ "${_LOCAL_PHPENV_ACTIVE:-0}" != 1 ]; then
  _LOCAL_PHPENV_OLD_PATH="${PATH}"
  _LOCAL_PHPENV_OLD_ROOT="${PHPENV_ROOT-}"
  _LOCAL_PHPENV_OLD_VERSION="${PHPENV_VERSION-}"
  _LOCAL_PHPENV_HAD_ROOT="${PHPENV_ROOT+x}"
  _LOCAL_PHPENV_HAD_VERSION="${PHPENV_VERSION+x}"
  _LOCAL_PHPENV_OLD_LIBRARY_PATH="${LD_LIBRARY_PATH-}"
  _LOCAL_PHPENV_HAD_LIBRARY_PATH="${LD_LIBRARY_PATH+x}"
  _LOCAL_PHPENV_ACTIVE=1
fi

export PHPENV_ROOT="${_phpenv_workspace_phpenv_root}"
export PHPENV_VERSION="8.3.6"
export LD_LIBRARY_PATH="${PHPENV_ROOT}/lib${_LOCAL_PHPENV_OLD_LIBRARY_PATH:+:${_LOCAL_PHPENV_OLD_LIBRARY_PATH}}"
export PATH="${PHPENV_ROOT}/shims:${PHPENV_ROOT}/bin:${_LOCAL_PHPENV_OLD_PATH}"

deactivate_phpenv() {
  [ "${_LOCAL_PHPENV_ACTIVE:-0}" = 1 ] || return 0
  export PATH="${_LOCAL_PHPENV_OLD_PATH}"
  if [ -n "${_LOCAL_PHPENV_HAD_ROOT}" ]; then
    export PHPENV_ROOT="${_LOCAL_PHPENV_OLD_ROOT}"
  else
    unset PHPENV_ROOT
  fi
  if [ -n "${_LOCAL_PHPENV_HAD_VERSION}" ]; then
    export PHPENV_VERSION="${_LOCAL_PHPENV_OLD_VERSION}"
  else
    unset PHPENV_VERSION
  fi
  if [ -n "${_LOCAL_PHPENV_HAD_LIBRARY_PATH}" ]; then
    export LD_LIBRARY_PATH="${_LOCAL_PHPENV_OLD_LIBRARY_PATH}"
  else
    unset LD_LIBRARY_PATH
  fi
  unset _LOCAL_PHPENV_OLD_PATH _LOCAL_PHPENV_OLD_ROOT _LOCAL_PHPENV_OLD_VERSION
  unset _LOCAL_PHPENV_OLD_LIBRARY_PATH _LOCAL_PHPENV_HAD_LIBRARY_PATH
  unset _LOCAL_PHPENV_HAD_ROOT _LOCAL_PHPENV_HAD_VERSION _LOCAL_PHPENV_ACTIVE
  unset -f deactivate_phpenv
  hash -r
}

unset _phpenv_workspace_root _phpenv_workspace_phpenv_root
hash -r
