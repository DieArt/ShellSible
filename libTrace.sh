#!/usr/bin/env bash
set -o errtrace  # Trap errors in subshells and functions
set -o functrace # Trap functions too.
set -o errexit   # Exit on most errors (see the manual)
set -o noclobber # Prevent overwriting files.
#set -o nounset    # Treat unset variables as an error
set -o pipefail   # Pipelines return the exit status of the last command in the pipe that returned a non-zero return value.
set +o histexpand # Disable history expansion on interactive shell
varCrash=false    # Used to prevent multiple crash reports.

function ErrorHandler {
  local returnCode="${?}"
  if [[ "${varCrash}" == "false" ]]; then
    function _showMetadata {
      printf "[%s] [System:%s/%s] [Version:${BASH_VERSION}]\n" \
        "$(date +%Y-%m-%dT%H:%M:%S%z)" "$(uname -s)" "$(uname -m)" >&2
    }
    function _showPs {
      [[ -n $(command -v ps) ]] && {
        while IFS='$\n' read -r line; do
          printf "%s | ${line}\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" >&2
        done < <(ps -f $$)
      }
    }
    _showMetadata
    _showPs
    varCrash=true
  fi
  test ${returnCode} -ne 0 \
    && GetCallStack "${returnCode}"
  exit "${returnCode}"
}
function GetCallStack {
  local index returnCode=${1} \
    command="${BASH_COMMAND}" \
    functionStack=("${FUNCNAME[@]}") \
    sourceStack=("${BASH_SOURCE[@]}") \
    lineStack=("${BASH_LINENO[@]}")
  # Show stack trace.
  echo "========== STACK TRACE ==========" >&2
  echo "Error handler was triggered by ${command} as returns ${returnCode}."
  echo "Caused by: ${command}(${sourceStack[2]##*/}:${lineStack[1]})"
  for ((index = 2; index < ${#functionStack[@]}; index++)); do # Loop through the call stack
    if [[ ${#functionStack[@]} == $((index + 1)) ]]; then
      echo -e "        at .${functionStack[${index}]} (${0##*/}:${lineStack[${index}]})"
    else
      echo -e "        at ${functionStack[${index}]} (${sourceStack[${index} + 1]##*/}:${lineStack[${index}]})"
    fi
  done
}
trap 'ErrorHandler' ERR # Use ERR and EXIT traps all threads.
