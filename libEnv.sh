#!/usr/bin/env bash
[[ "${BASH_SOURCE[0]}" != "$0" ]] || { # Prevent executing this library.
  echo "Please a source this configuration file and do not run this script directly." && exit 1
}
libName="$(basename "${BASH_SOURCE[0]}" .sh)" && [[ -z "${loadedLibs[${libName}]}" ]] && { # Prevent double sourcing.
  loadedLibs[${libName}]="loaded" # Need to be "declare -gA loadedLibs" in the main script before sourcing this library.
} || return 0
########################################################################################################################
# Prevent double sourcing.
libName="$(basename "${BASH_SOURCE[0]}" .sh)"
[[ -z "${loadedLibs["${libName}"]}" ]] && {
  loadedLibs["${libName}"]="loaded"
} || return 0
scriptPath=$(readlink -f -- "${BASH_SOURCE[-1]##*/}") # Full path of the script.
scriptName=$(basename "${scriptPath}")                # Name of the script.
scriptDir=$(dirname "${scriptPath}")                  # Absolute path of the script directory.

# Environment configuration:
declare -x \
  LC_ALL='C' \
  PAGER='LESS'
