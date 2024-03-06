#!/usr/bin/env bash
[[ "${BASH_SOURCE[0]}" != "$0" ]] || { # Prevent executing this library.
  echo "Please a source this configuration file and do not run this script directly." && exit 1
}
libName="$(basename "${BASH_SOURCE[0]}" .sh)" && [[ -z "${loadedLibs[${libName}]}" ]] && { # Prevent double sourcing.
  loadedLibs[${libName}]="loaded" # Need to be "declare -gA loadedLibs" in the main script before sourcing this library.
} || return 0
########################################################################################################################
logToConsole="${logToConsole:=true}"
logToFile="${logToFile:=false}"
logToSyslog="${logToSyslog:=false}"
#._func_================================================================================================================
#.Log._Initialize()
#.  Description : Initialize lib log.
function ShellSible.Log._Initialize {
  declare -g logToConsole logToFile logToSyslog
  local logFileName logFilePath logFileDir # TODO: var logFileName is not used.

  binaryList=(tee logger date) # TODO: Refactor check all binaries before logging and exit.
  for binary in "${binaryList[@]}"; do
    Test.CommandIsAvailable "${binary}" || {
      Log.Err "Binary: '${binary}' not found in a path."
      return 1
    }
  done

  # Create log file and open file descriptor if logToFile set as true.
  if test "${logToFile}" == 'true'; then
    Test.FileIsWritable "${logFileDir}" \
      && {
        # Create log file and open file descriptor.
        # shellcheck disable=SC2188
        >"${logFilePath}" \
          && exec 5>"${logFilePath}"
      } \
      || {
        logToFile='false'
        Log.Err "Log file directory is not writable: ${logFileDir}"
        Log.Notice "Log: File output as disabled."
        return 1
      }
  fi
}
#._func_================================================================================================================
#._Log.Log(logLevel, logMessage)
#.  Description:
#.    Log message to syslog, file and/or stdout.
#.
#.  Arguments:
#.    [enum]logLevel:     [emerg|alert|crit|err|warning|notice|info|debug].
#.    [string]logMessage: Message.
#.
#.  Variables:
#.    [string]appName:    Name of the application used for logging to syslog.
#.    [bool]logToConsole: Set as 'true' to log to stdout.
#.    [bool]logToFile:    Set as 'true' to log to file.
#.    [bool]logToSyslog:  Set as 'true' to log to syslog.
function ShellSible.Log._Log {
  local logLevel="${1}" logMessage="${2}"
  local -A logDisplayLogLevel logLevelInt

  logDisplayLogLevel=(
    ['emerg']="EMERG"
    ['alert']="ALERT"
    ['crit']="CRIT"
    ['err']="ERROR"
    ['warning']="WARN"
    ['notice']="NOTICE"
    ['info']="INFO"
    ['debug']="DEBUG"
  ) # Transform log level from syslog format.

  logLevelInt=(
    ['emerg']=0
    ['alert']=1
    ['crit']=2
    ['err']=3
    ['warning']=4
    ['notice']=5
    ['info']=6
    ['debug']=7
  ) # Transform log level to integer.

  test -z "${LOG_LEVEL}" \
    && LOG_LEVEL='info' # If LOG_LEVEL is not set, set it to 'info'. # TODO: Refactor this.

  test "${logLevelInt[$logLevel]}" -gt "${logLevelInt[$LOG_LEVEL]}" \
    && return 0 # Check if needed to log.

  logMessage="[$(date +%Y-%m-%dT%H:%M:%S%z)][${logDisplayLogLevel[$logLevel]}][${FUNCNAME[2]}] ${logMessage}"

  test "${logToSyslog}" == 'true' \
    && logger -t "${scriptName}" -p "${logLevel}" "${logMessage}" # Send message to syslog.

  test "${logToFile}" == 'true' \
    && echo "${logMessage}" >>"${scriptLogDir}${scriptName}.log" # Write message to log file.

  test "${logToConsole}" == 'true' \
    && echo -e "${logMessage}" # Print message to stdout/console.

  return 0
}
#._func_================================================================================================================
#. ShellSible.Log.Emerg(logMessage)
#. Description : Log message with emerg level.
#.
#. Arguments :
#.   - logMessage : message to log.
function ShellSible.Log.Emerg {
  local logMessage="${*}"
  ShellSible.Log._Log 'emerg' "${logMessage}"
}
#._func_================================================================================================================
#. ShellSible.Log.Alert(logMessage)
#. Description : Log message with alert level.
#.
#. Arguments :
#.   - logMessage : message to log.
function ShellSible.Log.Alert {
  local logMessage="${*}"
  ShellSible.Log._Log 'alert' "${logMessage}"
}
#._func_================================================================================================================
#. ShellSible.Log.Crit(logMessage)
#. Description : Log message with crit level.
#.
#. Arguments :
#.   - logMessage : message to log.
function ShellSible.Log.Crit {
  local logMessage="${*}"
  ShellSible.Log._Log 'crit' "${logMessage}"
}
#._func_================================================================================================================
#. ShellSible.Log.Err(logMessage)
#. Description : Log message with err level.
#.
#. Arguments :
#.   - logMessage : message to log.
function ShellSible.Log.Err {
  local logMessage="${*}"
  ShellSible.Log._Log 'err' "${logMessage}"
}
#._func_================================================================================================================
#. ShellSible.Log.Error(logMessage)
#. Description : Log message with error level.
#.
#. Arguments :
#.   - logMessage : message to log.
function ShellSible.Log.Error {
  local logMessage="${*}"
  ShellSible.Log._Log 'err' "${logMessage}"
}
#._func_================================================================================================================
#. ShellSible.Log.Warning(logMessage)
#. Description : Log message with warning level.
#.
#. Arguments :
#.   - logMessage : message to log.
function ShellSible.Log.Warning {
  local logMessage="${*}"
  ShellSible.Log._Log 'warning' "${logMessage}"
}
#._func_================================================================================================================
#. ShellSible.Log.Notice(logMessage)
#. Description : Log message with notice level.
#.
#. Arguments :
#.   - logMessage : message to log.
function ShellSible.Log.Notice {
  local logMessage="${*}"
  ShellSible.Log._Log 'notice' "${logMessage}"
}
#._func_================================================================================================================
#. ShellSible.Log.Info(logMessage)
#. Description : Log message with info level.
#.
#. Arguments :
#.   - logMessage : message to log.
function ShellSible.Log.Info {
  local logMessage="${*}"
  ShellSible.Log._Log 'info' "${logMessage}"
}
#._func_================================================================================================================
#. ShellSible.Log.Debug(logMessage)
#. Description: Log message with debug level.
#.
#. Arguments:
#.   - logMessage: message to log.
function ShellSible.Log.Debug {
  local logMessage="${*}"
  ShellSible.Log._Log 'debug' "${logMessage}"
}
