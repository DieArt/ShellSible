#!/usr/bin/env bash

# shellcheck disable=SC2016
readonly macroParseArgs='local -A args; local -a xArgs; _parseArgs args extraArgs "${@}"' # Macro to parse arguments
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
function test {
  eval "${macroParseArgs}"
  for key in "${!args[@]}"; do
    echo "$key: ${args[$key]}"
  done
  for argument in "${extraArgs[@]}"; do
    echo "$argument"
  done
}
