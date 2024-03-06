#!/usr/bin/env bash
[[ "${BASH_SOURCE[0]}" != "$0" ]] || { # Prevent executing this library.
  echo "Please a source this configuration file and do not run this script directly." && exit 1
}
libName="$(basename "${BASH_SOURCE[0]}" .sh)" && [[ -z "${loadedLibs[${libName}]}" ]] && { # Prevent double sourcing.
  loadedLibs[${libName}]="loaded" # Need to be "declare -gA loadedLibs" in the main script before sourcing this library.
} || return 0
########################################################################################################################
[[ ${BASH_SOURCE[-1]} == ${0} ]] || {
  echo -e "Main script as source detected:\n\tdebugging mode enabled."
  declare -g scriptDebug=true
}
[[ -n "${scriptDebug}" ]] \
  || set -o errexit    # Disable exit on error if debugging mode is enabled.
set -o errtrace        # Trap errors in subshells and functions
set -o functrace       # Trap functions too.
set -o pipefail        # Trap return code in a pipeline.
set -o noclobber       # Prevent overwriting files.
set +o histexpand      # Disable history expansion on interactive shell
declare varTrace=false # Used to prevent many trace reports.

#._func_================================================================================================================
#._Trace.Initialize
#.  Description:
#.    Initialize the library.
function Trace._Initialize {
  local binaryList=('command' 'printf' 'basename') # List of binaries to check.
  Trace._CheckBinary "${binaryList[@]}"
}
#._func_================================================================================================================
#._Trace.CheckBinary(binaryList)
#.  Description:
#.    Check if all binaries are available in the path.
#.
#.  Arguments:
#.    [array]binaryList: List of binaries to check.
function Trace._CheckBinary {
  local binaryList=("${@}")

  for binary in "${binaryList[@]}"; do # Check if all binaries are available.
    command -v -- "${binary}" &>/dev/null \
      || missingBinaryList+=("${binary}")
  done

  [[ ${#missingBinaryList[@]} == 0 ]] || { # If there are missing binaries.
    echo -e "[$(date +%Y-%m-%dT%H:%M:%S%z)][${FUNCNAME[1]}][EMERG] '${missingBinaryList[*]}' not found in a path."
    return 1
  }
}
#._func_================================================================================================================
#._Trace.Log(logMessage)
#.  Description:
#.    Log message.
#.
#.  Arguments:
#.    [string]logMessage: Message to log.
function Trace._LogCrash { # Log crash message.
  local logMessage="${1}"
  printf "[$(date +%Y-%m-%dT%H:%M:%S%z)][%s][EMERG] %s\n" \
    "$(basename -- "${0}")" "${logMessage}"
}
#._func_================================================================================================================
#._Trace.ErrorHandler()
#.  Description:
#.    Error handler.
function Trace._ErrorHandler { # Error handler.
  local returnCode="${?}"
  set +o xtrace                                                        # Disable trace.
  if [[ ${varTrace} == 'false' ]] && [[ "${returnCode}" -ne 0 ]]; then # Prevent multiple trace reports.
    #varTrace=true
    Trace._GetCallStack "${returnCode}"
    Trace._LogCrash "Exit code: ${returnCode}"
  fi
  [[ -n "${scriptDebug}" ]] \
    || exit "${returnCode}"
}
#._func_================================================================================================================
#._Trace.GetCallStack()
#.  Description:
#.    Get the call stack.
function Trace._GetCallStack { # Get the call stack.
  local index \
    returnCode="${1}" \
    command="${BASH_COMMAND}" \
    functionStack=("${FUNCNAME[@]}") \
    sourceStack=("${BASH_SOURCE[@]}") \
    lineStack=("${BASH_LINENO[@]}")

  Trace._LogCrash "Error handler was triggered by: ${command}"
  Trace._LogCrash "Caused by: ${command} (${sourceStack[2]##*/}:${lineStack[1]})"

  for ((index = 2; index < ${#functionStack[@]}; index++)); do # Loop through the call stack
    if [[ ${#functionStack[@]} == $((index + 1)) ]]; then
      Trace._LogCrash "        at .${functionStack[${index}]}(${0##*/}:${lineStack[${index}]})"
    else
      Trace._LogCrash "        at ${functionStack[${index}]}(${sourceStack[${index} + 1]##*/}:${lineStack[${index}]})"
    fi
  done
}

Trace._Initialize              # Initialize the library.
trap 'Trace._ErrorHandler' ERR # Use ERR and EXIT traps all threads.

# Unset the functions useless after initialization.
unset -f \
  Trace._Initialize \
  Trace._CheckBinary
