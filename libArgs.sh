#!/usr/bin/env bash
[[ "${BASH_SOURCE[0]}" != "$0" ]] || { # Prevent executing this library.
  echo "Please a source this configuration file and do not run this script directly." && exit 1
}
libName="$(basename "${BASH_SOURCE[0]}" .sh)" && [[ -z "${loadedLibs[${libName}]}" ]] && { # Prevent double sourcing.
  loadedLibs[${libName}]="loaded" # Need to be "declare -gA loadedLibs" in the main script before sourcing this library.
} || return 0
########################################################################################################################
#._macro_===============================================================================================================
#._macroParseArgs
#.  Description:
#.    Macro to parse arguments.
#.
#.  Usage:
#.    eval "${macroParseArgs}"
readonly macroParseArgs='local -A args; local -a xArgs; _parseArgs args extraArgs "${@}"' # Macro to parse arguments
#._func_================================================================================================================
#._parseArgs(args, extraArgs, ...)
#.  Description:
#.    Parse arguments and store them in the args array and extra arguments in the extraArgs array.
#.
#.  Arguments:
#.    [ref]args: Array to store the parsed arguments.
#.    [ref]extraArgs: Array to store the extra arguments.
#.    ...: Arguments to parse.
function _parseArgs {                                                                     # Function to parse arguments
  local -n _args="${1}" _extraArgs="${2}"                                                 # Use ref to store the parsed arguments
  local doubleDash='false'                                                                # Use to check if we have already encountered a double dash
  for argument in "${@}"; do                                                              # Loop through the arguments
    if [[ "${doubleDash}" == 'false' && "${argument}" == '--' ]]; then                    # Check if the argument is a double dash
      doubleDash='true'                                                                   # Set the double dash flag
      continue                                                                            # Skip to the next argument
    elif [[ "${doubleDash}" == 'false' && "${argument}" =~ ^--?([^=]+)=(.*) ]]; then      # Check if the argument is in the format --key=value or -key=value or key=value
      local key="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"                           # Extract the key and value from the argument
      _args["${key}"]="${value}"                                                          # Store the key-value pair in the args array
    else                                                                                  # If the argument is not in the format --key=value or -key=value or key=value
      _extraArgs+=("${argument}")                                                         # Store the argument in the extraArgs array
    fi                                                                                    # End the if statement
  done                                                                                    # End the loop
}                                                                                         # End the function
#._func_================================================================================================================
#._test.parseArgs
#.  Description:
#.    Test the _parseArgs function.
#.
#.  Usage:
#.    _test.parseArgs [args...]
function _test.parseArgs { # Test the _parseArgs function
  eval "${macroParseArgs}"
  for key in "${!args[@]}"; do
    echo "$key: ${args[$key]}"
  done
  for argument in "${extraArgs[@]}"; do
    echo "$argument"
  done
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
