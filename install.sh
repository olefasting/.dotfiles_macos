#!/usr/bin/env zsh

set -e

PROJECT_NAME=".dotfiles_macos"
PROJECT_VERSION="0.1.0"

ENV_FILE_PATH="${HOME}/.zshenv"

CONTENT_BLOCK_BEGIN="begin ${PROJECT_NAME}"
CONTENT_BLOCK_END="end ${PROJECT_NAME}"

COMMENT_HASH_LINE="hash_line"
COMMENT_SLASH_LINE="slash_line"
COMMENT_SLASH_BLOCK="slash_block"

COMMENT_HASH_LINE_BEGIN="#"
COMMENT_SLASH_LINE_BEGIN="//"
COMMENT_SLASH_BLOCK_BEGIN="/*"
COMMENT_SLASH_BLOCK_END="*/"

LOG_LEVEL_INFO="info"
LOG_LEVEL_WARNING="warning"
LOG_LEVEL_ERROR="error"

LOG_PREFIX_INFO="INFO"
LOG_PREFIX_WARNING="WARNING"
LOG_PREFIX_ERROR="ERROR"

LOG_FORMAT="[_pfx_]: _msg_"

DEFAULT_ERROR_MESSAGE="An unknown error occurred"

error_exit() {
  local msg
  msg="${1}"
  [ -z "${msg}" ] && msg="${DEFAULT_ERROR_MESSAGE}"

  error "${msg}"
  exit 1
}

function is_log_level() {
  case "${1}" in
  "${LOG_LEVEL_INFO}" | "${LOG_LEVEL_WARNING}" | "${LOG_LEVEL_ERROR}")
    echo "true"
    ;;
  *)
    echo "false"
    ;;
  esac

  return 0
}

function to_log_level() {
  local log_level
  log_level="$(echo "${1}" | tr '[:upper]' '[:lowe]')"

  case "${log_level}" in
  "warn")
    log_level="${LOG_LEVEL_WARNING}"
    ;;
  "err")
    log_level="${LOG_LEVEL_ERROR}"
    ;;
  *)
    if [[ "$(is_log_level "${log_level}")" == "false" ]]; then
      echo "Invalid log level'${1}'!"
      return 1
    fi
    ;;
  esac

  echo "${log_level}"

  return 0
}

function to_log_prefix() {
  local log_level
  log_level=$(to_log_level "${1}")

  local pfx
  case "${log_level}" in
  "${LOG_LEVEL_INFO}")
    pfx="${LOG_PREFIX_INFO}"
    ;;
  "${LOG_LEVEL_WARNING}")
    pfx="${LOG_PREFIX_WARNING}"
    ;;
  "${LOG_LEVEL_ERROR}")
    pfx="${LOG_PREFIX_ERROR}"
    ;;
  esac

  echo "${pfx}"

  return 0
}

function format_log_output() {
  if [ -z "${1}" ]; then
    echo "Attempting to format log output but no prefix was specified!"
    return 1
  elif [ -z "${2}" ]; then
    echo "Attempting to format log output but no message was specified!"
    return 1
  else
    local fmt
    fmt="${LOG_FORMAT/_pfx_/${1}}"
    echo "${fmt/_msg_/${2}}"
  fi

  return 0
}

function log() {
  local log_level

  if [ -z "${2}" ]; then
    log_level="${LOG_LEVEL_INFO}"
  else
    log_level=$(to_log_level "${1}")
  fi

  local pfx
  pfx="$(to_log_prefix "${log_level}")"

  local msg

  if [ -z "${2}" ]; then
    msg="${1}"
  else
    msg="${2}"
  fi

  [ -z "${msg}" ] && [[ "${log_level}" == "${LOG_LEVEL_ERROR}" ]] && msg="${DEFAULT_ERROR_MESSAGE}"

  [ -n "${msg}" ] && format_log_output "${pfx}" "${msg}"

  return 0
}

function info() {
  [ -z "${1}" ] || log "${LOG_LEVEL_INFO}" "${1}"

  return 0
}

function warn() {
  [ -z "${1}" ] || log "${LOG_LEVEL_WARNING}" "${1}"

  return 0
}

function error() {
  local msg
  msg="${1}"

  [ -z "${msg}" ] && msg="${DEFAULT_ERROR_MESSAGE}"

  log "${LOG_LEVEL_ERROR}" "${msg}"

  return 0
}

function assert_is_project_dir() {
  local file_name
  file_name=$(basename "${0}")
  if [ ! -e "${1}/.state" ] && [ ! -e "${1}/${file_name}" ]; then
    echo "The directory '${1}' is not the ${PROJECT_NAME} root directory. Either provide the correct file_path as an argument or execute the script from the ${PROJECT_NAME} root directory"
    return 1
  fi

  return 0
}

function revert_file() {
  local comment_type
  comment_type=$(to_comment_type "${1}")

  local file_path
  file_path="${2}"

  if [ ! -e "${file_path}" ]; then
    echo "Invalid path '${file_path}'. Unable to revert file!"
    return 1
  fi

  local begin_block
  begin_block=$(to_comment "${comment_type}" "${CONTENT_BLOCK_BEGIN}")

  local end_block
  end_block=$(to_comment "${comment_type}" "${CONTENT_BLOCK_END}")

  local buffer
  buffer=$(sed "/${begin_block}/,/${end_block}/d" "${file_path}")

  echo "${buffer}" >"${file_path}"

  return 0
}

function prepend_to_file() {
  local comment_type
  comment_type=$(to_comment_type "${1}")

  local content
  content="${2}"

  local file_path
  file_path="${3}"

  if [ ! -f "${file_path}" ]; then
    echo "Invalid path '${file_path}'. Unable to prepend to file!"
    return 1
  fi

  cp "${file_path}" "${file_path}.bak"

  revert_file "${comment_type}" "${file_path}"

  local original_content
  original_content=$(cat "${file_path}")

  {
    to_comment "${comment_type}" "${CONTENT_BLOCK_BEGIN}";
    echo "${content}";
    to_comment "${comment_type}" "${CONTENT_BLOCK_END}";
    printf "\n"
  } >"${file_path}"

  echo "${original_content}" >>"${file_path}"
}

function append_to_file() {
  local comment_type
  comment_type=$(to_comment_type "${1}")

  local content
  content="${2}"

  local file_path
  file_path="${3}"

  [ -z "${file_path}" ] && touch "${file_path}"

  if [ ! -f "${file_path}" ]; then
    echo "Invalid path '${file_path}'. Unable to append to file!"
    return 1
  fi

  cp "${file_path}" "${file_path}.bak"

  revert_file "${comment_type}" "${file_path}"

  {
    printf "\n";
    to_comment "${comment_type}" "${CONTENT_BLOCK_BEGIN}";
    echo "${content}";
    to_comment "${comment_type}" "${CONTENT_BLOCK_END}";
    printf "\n"
  } >>"${file_path}"

  return 0
}

function to_comment_type() {
  if [ -z "${1}" ]; then
    echo "No argument provided when calling to_comment_type!"
    return 1
  fi

  local comment_type
  comment_type="$(echo "${1}" | tr '[:upper]' '[:lowe]')"

  case "${comment_type}" in
  "${COMMENT_HASH_LINE}" | "${COMMENT_SLASH_BLOCK}" | "${COMMENT_SLASH_BLOCK}") ;;

  *)
    echo "Invalid comment type '${1}'"
    return 1
    ;;
  esac

  echo "${comment_type}"

  return 0
}

function to_comment() {
  local comment_type
  comment_type=$(to_comment_type "${1}")

  if [ -n "${2}" ]; then
    local is_block
    local begin
    local end

    case "${comment_type}" in
    "${COMMENT_HASH_LINE}")
      is_block="false"
      begin="${COMMENT_HASH_LINE_BEGIN}"
      end=""
      ;;
    "${COMMENT_SLASH_LINE}")
      is_block="false"
      begin="${COMMENT_SLASH_LINE_BEGIN}"
      end=""
      ;;
    "${COMMENT_SLASH_BLOCK}")
      is_block="true"
      begin="${COMMENT_SLASH_BLOCK_BEGIN}"
      end="${COMMENT_SLASH_BLOCK_END}"
      ;;
    esac

    local msg
    if [[ "${is_block}" == "true" ]]; then
      msg="${begin}\n${2}\n${end}"
    else
      for line in ${2}; do
        msg="${msg}${begin} ${line}"
      done
    fi

    echo "${msg}"
  fi

  return 0
}

zmodload zsh/mapfile

DOTFILES_PATH="${PWD}"
[ -z "${1}" ] || DOTFILES_PATH="${1}"

assert_is_project_dir "${DOTFILES_PATH}"

[ -e "${DOTFILES_PATH}/.state" ] || mkdir -p "${DOTFILES_PATH}/.state"

log "setting up zsh"
append_to_file "${COMMENT_HASH_LINE}" "source ${DOTFILES_PATH}/zsh/.zshenv" "${ENV_FILE_PATH}"
