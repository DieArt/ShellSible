#!/usr/bin/env bash
[[ "${BASH_SOURCE[0]}" != "$0" ]] || { # Prevent executing this library.
  echo "Please a source this configuration file and do not run this script directly." && exit 1
}
libName="$(basename "${BASH_SOURCE[0]}" .sh)" && [[ -z "${loadedLibs[${libName}]}" ]] && { # Prevent double sourcing.
  loadedLibs[${libName}]="loaded" # Need to be "declare -gA loadedLibs" in the main script before sourcing this library.
} || return 0
########################################################################################################################
# Example documentation for functions.
#####_Begin_Example_#####
#._func_================================================================================================================
#.ExempleLib.ExempleFunction(arg1, arg2, arg3,...)
#.  Description:
#.    Short description of the function.
#.
#.  Usage:
#.    ExempleLib.ExempleFunction arg1 arg2 arg3
#.
#.  Arguments:
#.    [type]name:     Description.
#.
#.  Variables:
#.    [type]name:    Description.
#.
#.  Returns:
#.    [-1]:        Description.
#####_End_Example_#####

#._func_================================================================================================================
#.Doc.Search(query)
#.  Description:
#.    Search documentation in source code or show all documentation if no arguments are given.
#.
#.  Arguments:
#.    [string]query: keyword for search.
function Doc.Search {
  local query docPrefix docFunctionHeader

  query="$1"
  docPrefix='#\.'
  docFunctionHeader='_func_'

  grep -REh "^${docPrefix}" "${scriptLibDir}" \
    | sed "s=${docPrefix}==" \
    | awk -v RS="${docFunctionHeader}" -v ORS='' "/${query}/"

}

#._func_================================================================================================================
#.Doc.GetFunctions()
#.  Description:
#.    Show all functions in the script.
#.
#.  Returns:
#.    [-1]:        Description.
function Doc.GetFunctions {
  local func
  for func in $(declare -f | grep '()' | grep '^[A-Z]' | cut -d' ' -f1); do
    Log.Info "Loaded: \"${func}\""
  done
}
