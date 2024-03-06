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
#._Log.Initialize()
#.  Description : Initialize lib log.
function _Log.Initialize {
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
        > "${logFilePath}" \
          && exec 5> "${logFilePath}"
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
function _Log.Log {
  local logLevel message
  logLevel="${1}"
  message="${2}"

  # Transform log level from syslog format.
  declare -A logDisplayLogLevel=(
    ['emerg']="EMERG"
    ['alert']="ALERT"
    ['crit']="CRIT"
    ['err']="ERROR"
    ['warning']="WARN"
    ['notice']="NOTICE"
    ['info']="INFO"
    ['debug']="DEBUG"
    ['exec']="EXEC"
  )

  # Transform log level to integer.
  declare -A logLevelInt=(
    ['emerg']=0
    ['alert']=1
    ['crit']=2
    ['err']=3
    ['warning']=4
    ['notice']=5
    ['info']=6
    ['debug']=7
    ['exec']=6
  )

  [[ "${logLevelInt[$logLevel]}" != 'EXEC' ]] || blank=' '

  # If LOG_LEVEL is not set, set it to 'info'. # TODO: Refactor this.
  test -z "${LOG_LEVEL}" \
    && LOG_LEVEL='info'

  # Check if log level need to be logged. # TODO: Refactor this.
  test "${logLevelInt[$logLevel]}" -gt "${logLevelInt[$LOG_LEVEL]}" \
    && return 0

  # Format log message.
  message="[$(date +%Y-%m-%dT%H:%M:%S%z)][${logDisplayLogLevel[$logLevel]}][${FUNCNAME[2]}]${blank}${logMessage}"

  # Log to syslog.
  test "${logToSyslog}" == 'true' \
    && logger -t "${scriptName}" -p "${logLevel}" "${logMessage}"

  # Log to file.
  test "${logToFile}" == 'true' \
    && echo "${logMessage}" >> "${scriptLogDir}${scriptName}.log"

  # Log to stdout.
  test "${logToConsole}" == 'true' \
    && echo -e "${logMessage}"

  return 0
}
#._func_================================================================================================================
#. Log.Emerg(logMessage)
#. Description : Log message with emerg level.
#.
#. Arguments :
#.   - logMessage : message to log.
function Log.Emerg {
  local message="${*}"
  _Log.Log 'emerg' "${message}"
}
#._func_================================================================================================================
#. Log.Alert(logMessage)
#. Description : Log message with alert level.
#.
#. Arguments :
#.   - logMessage : message to log.
function Log.Alert {
  local logMessage="${*}"
  _Log.Log 'alert' "${logMessage}"
}
#._func_================================================================================================================
#. Log.Crit(logMessage)
#. Description : Log message with crit level.
#.
#. Arguments :
#.   - logMessage : message to log.
function Log.Crit {
  local logMessage="${*}"
  _Log.Log 'crit' "${logMessage}"
}
#._func_================================================================================================================
#. Log.Err(logMessage)
#. Description : Log message with err level.
#.
#. Arguments :
#.   - logMessage : message to log.
function Log.Err {
  local logMessage="${*}"
  _Log.Log 'err' "${logMessage}"
}
#._func_================================================================================================================
#. Log.Error(logMessage)
#. Description : Log message with error level.
#.
#. Arguments :
#.   - logMessage : message to log.
function Log.Error {
  local logMessage="${*}"
  _Log.Log 'err' "${logMessage}"
}
#._func_================================================================================================================
#. Log.Warning(logMessage)
#. Description : Log message with warning level.
#.
#. Arguments :
#.   - logMessage : message to log.
function Log.Warning {
  local logMessage="${*}"
  _Log.Log 'warning' "${logMessage}"
}
#._func_================================================================================================================
#. Log.Notice(logMessage)
#. Description : Log message with notice level.
#.
#. Arguments :
#.   - logMessage : message to log.
function Log.Notice {
  local logMessage="${*}"
  _Log.Log 'notice' "${logMessage}"
}
#._func_================================================================================================================
#. Log.Info(logMessage)
#. Description : Log message with info level.
#.
#. Arguments :
#.   - logMessage : message to log.
function Log.Info {
  local logMessage="${*}"
  _Log.Log 'info' "${logMessage}"
}
#._func_================================================================================================================
#. Log.Debug(logMessage)
#. Description: Log message with debug level.
#.
#. Arguments:
#.   - logMessage: message to log.
function Log.Debug {
  local logMessage="${*}"
  _Log.Log 'debug' "${logMessage}"
}
#._func_================================================================================================================
#. Log.Exec(logMessage)
#. Description: Log message with info level.
#.
#. Arguments:
#.   - logMessage: message to log.
function Log.Exec {
  local logMessage="${*}"
  _Log.Log 'exec' "${logMessage}"
}
