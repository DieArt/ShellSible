#!/usr/bin/env bash
VERBOSE='true' # Enable verbose mode.
# Set environment.
LC_ALL='C.UTF-8'                         # Enable UTF-8 support.
selfPath=$(readlink -f "$0")             # Get the absolute path of the script.
selfDir=$(dirname "$(readlink -f "$0")") # Get the absolute path of the script.
sqlDatabase="${selfDir}/var/rlyeh.db"    # Database file.

appName='test'       # Application name.
appVersion='0.0.1'       # Application version.
pathTmp="/tmp/test" # Temporary directory.

export VERBOSE LC_ALL selfPath selfDir sqlDatabase appName appVersion pathTmp
unalias -a

if test "${0}" = "${BASH_SOURCE[0]}"; then
  echo "Please source ${0}, not run." >&2
  exit 1
fi

#Log.Initialize() {
#  teeBinary=$(which tee) || Log.ErrorAndExit "Couldn't find tee binary."
#}

# Initialize.
function Initialize {
  source "${selfDir}/lib/libSystem.sh"
  for lib in "${selfDir}"/lib/lib*.sh; do
    echo "Loading library: ${lib}"
    source "${lib}"
  done
}

#!/usr/bin/env bash
Core.Execute() {
  local taskIdentifier
  taskIdentifier="${RANDOM}${RANDOM}"
  eval "$@" | while read -r line; do
    echo -e "$(System.GetDate) [${FUNCNAME[1]}] | ${taskIdentifier} | ${line}"
  done
}
Core.ExecuteInInteractiveMode() {
  eval "$@"
}
Core.GetSelfName() {
  SOURCE=${BASH_SOURCE[0]}
  while [ -h "${SOURCE}" ]; do
    DIR=$(cd -P "$(dirname "${SOURCE}")" >/dev/null 2>&1 && pwd)
    SOURCE=$(readlink "${SOURCE}")
    test ${SOURCE} != /* && SOURCE=${DIR}/${SOURCE}
  done
  echo "$(basename "${SOURCE}")"
}
Core.GetSelfPath() {
  SOURCE=${BASH_SOURCE[0]}
  while [ -h "${SOURCE}" ]; do
    DIR=$(cd -P "$(dirname "${SOURCE}")" >/dev/null 2>&1 && pwd)
    SOURCE=$(readlink "${SOURCE}")
    test ${SOURCE} != /* && SOURCE=${DIR}/${SOURCE}
  done
  DIR=$(cd -P "$(dirname "${SOURCE}")" >/dev/null 2>&1 && pwd)
  echo "${DIR}"
}
Core.LoadModule() {
  local moduleList module
  moduleList="${*}"
  for module in $moduleList; do
    test -n "${module}" || Logging.PrintErrorAndExit "Module not specified."
    test -f "${module}" || Logging.PrintErrorAndExit "Module not existing."
    test -r "${module}" || Logging.PrintErrorAndExit "Module is not readable."
    if source "${module}"; then
      Logging.PrintVerbose "Module $(echo ${module} | sed 's=^./lib/mod_==;s=.sh$==') loaded"
    else
      Logging.PrintError "Error on loading module: \"${module}\"."
      return 1
    fi
  done
}
Crypto.CascadeEncryptStream() {
  ${opensslBinary} enc -base64 -A
}
Crypto.DecodeStream() {
  ${opensslBinary} enc -base64 -d
}
Crypto.EncodeStream() {
  ${opensslBinary} enc -base64 -A
}
Crypto.EncryptStream() {
  local cipher="${1}"
  local password="${2}"
  Test.VarIsSet "${cipher}" || Log.Fatal "Cipher not specified."
  Test.VarIsSet "${password}" || Log.Fatal "Password not specified."
  Test.VarIsSet "$(Crypto.ListCiphers | grep -E "${cipher}")" || Log.Fatal "Cipher not supported."
  ${opensslBinary} enc -"${cipher}" -md -pass pass:"${password}" -pbkdf2 -salt
}
Crypto.GenerateEncodedSshPrivateKey() {
  local privateKey
  privateKey="$(
    Crypto.EncodeStream <<<"$(exec 3>&1 &&
      "${sshKeyGenBinary}" -qt ed25519 -N '' -f /proc/self/fd/3 <<<'y' &>/dev/null)"
  )"
  echo "${privateKey}"
}
Crypto.GenerateEncodedSshPublicKey() {
  local publicKey privateKey
  privateKey="${1}"
  test -n "${privateKey}" || Log.Fatal "Private key not specified."
  publicKey="$(
    Crypto.EncodeStream <<<"$(${sshKeyGenBinary} -y -f <(Crypto.DecodeStream <<<"${privateKey}"))"
  )"
  echo "${publicKey}"
}
Crypto.GetCiphersList() {
  ${opensslBinary} enc -list | sed -n '/^-/p' | tr ' ' '\n' | sed '/^$/d;s/^-//'
}
Crypto.GetHashAlgorithmList() {
  if test -z "${lHashAlgorithm}"; then
    lHashAlgorithm=$(
      ${opensslBinary} dgst -list | # Get the list of supported hash algorithms.
        sed -n '/^-/p' |            # Keep only the lines with the hash algorithms.
        tr ' ' '\n' |               # Replace space by newline.
        sed '/^$/d;s/^-//'          # Remove empty lines and remove the dash.
    )
  fi
  echo "${lHashAlgorithm}"
}
Crypto.GetHashFile() {
  local filename hashAlgorithm
  filename="${1}"
  hashAlgorithm="${2}"
  test -n "${hashAlgorithm}" && Log.Verbose "Hash algorithm specified : ${hashAlgorithm}"
  test -n "${filename}" || Log.Error "File not specified."
  test -f "${filename}" || Log.Error "File not existing."
  test -r "${filename}" || Log.Error "File is not readable."
  test -n "$(Crypto.GetHashAlgorithmList | grep -E "${hashAlgorithm}")" || Log.Error "Hash algorithm not supported."
  ${opensslBinary} dgst -"${hashAlgorithm}" -r "${filename}" | ${cutBinary} --delimiter=' ' --fields=1
}
Crypto.GetHashStream() {
  local hashAlgorithm
  hashAlgorithm="${1:-blake2b512}"
  test -n "${hashAlgorithm}" && Log.Verbose "Hash algorithm specified : ${hashAlgorithm}" || Log.Fatal "Hash algorithm not specified."
  test -n "$(Crypto.GetHashAlgorithmList | grep -E "^${hashAlgorithm}$")" && Log.Verbose "Hash algorithm supported : ${hashAlgorithm}" || Log.Fatal "Hash algorithm not supported."
  ${opensslBinary} dgst -"${hashAlgorithm}" -r | ${cutBinary} --delimiter=' ' --fields=1
}
Crypto.Initialize() {
  export opensslBinary=$(command -v 'openssl') || Log.ErrorAndExit "OpenSSL not found in path."
  export cutBinary=$(command -v 'cut') || Log.ErrorAndExit "Cut not found in path."
  export sshKeyGenBinary=$(command -v 'ssh-keygen') || Log.ErrorAndExit "ssh-keygen not found in path."
}
Database.Backup() {
  Log.Info "Prepare to backup database."
  echo backup db
  case $(System.SyncFile ${sqlDatabase}) in
  0)
    Log.Info "Database backup successful"
    ;;
  *)
    Log.Info "ERROR ON DATABASE BACKUP $?"
    ;;
  esac
}
Database.Check() {
  Log.Info "Check database integrity: $(Database.Query "PRAGMA integrity_check;")"
  Log.Info "Check database foreign key integrity: $(Database.Query "PRAGMA foreign_key_check;")"
}
Database.CreateDatabase() {
  Database.Transaction "$(<"etc/Rlyeh/schema.sql")" && Log.Verbose "Database created successfully" || Log.Error "ERROR ON DATABASE CREATE"
}
Database.DeleteDatabase() {
  rm -f "${sqlDatabase}" && Log.Verbose "Database delete successfully" || Log.Error "ERROR ON DATABASE DELETE"
}
Database.Dump() {
  ${sqliteBinary} -batch "${sqlDatabase}" .dump && Log.Verbose "Database dump successfully" || Log.Error "ERROR ON DATABASE DUMP"
}
Database.GetColumnList() {
  Database.Query "SELECT name FROM PRAGMA_TABLEINFO ('${1}');" && Log.Verbose "Get column list successful" || Log.Error "ERROR ON GET COLUMN LIST"
}
Database.GetDatabase() {
  if [[ -z ${sqlDatabase} ]]; then
    Log.ErrorAndExit "Database not set."
  else
    echo "${sqlDatabase}"
    Log.Verbose "Database get: ${sqlDatabase}"
  fi
}
Database.GetTableList() {
  Database.Query "SELECT name FROM sqlite_master WHERE type='table';" && Log.Verbose "Get table list successful" || Log.Error "ERROR ON GET TABLE LIST"
}
Database.Initialize() {
  sqliteBinary=$(command -v 'sqlite3') && Log.Verbose "Database initialized successfully : ${sqlDatabase}" || Log.ErrorAndExit "SQLite3 not found in path."
}
Database.Optimize() {
  Database.Query "
 PRAGMA FOREIGN_KEYS = ON;
 PRAGMA SYNCHRONOUS = NORMAL;
 PRAGMA CACHE_SIZE = 8192;
 PRAGMA TEMP_STORE = MEMORY;
 VACUUM;
 " && Log.Info "Database optimize successful" || Log.Info "ERROR ON DATABASE OPTIMIZE"
}
Database.Query() {
  ${sqliteBinary} -batch "${sqlDatabase}" <<<"${*}" && Log.Verbose "Query executed successfully: ${*}" || Log.Error "ERROR ON QUERY: ${*}"
}
Database.RecreateDatabase() {
  Database.DeleteDatabase
  Database.CreateDatabase
}
Database.Restore() {
  Log.Info "Prepare to restore database."
  echo restore db
  case $(System.SyncFile ${sqlDatabase}) in
  0)
    Log.Info "Database restore successful"
    ;;
  *)
    Log.Info "ERROR ON DATABASE RESTORE $?"
    ;;
  esac
}
Database.SetDatabase() {
  if Test.FileIsReadAndWrite "${1}"; then
    sqlDatabase="${1}"
    Log.Verbose "Database set: ${sqlDatabase}"
  else
    Log.ErrorAndExit "Failed to set database : ${1}"
  fi
}
Database.Sync() {
  Log.Info "Prepare to sync database on disk."
  System.SyncFile ${sqlDatabase} && Log.Info "Database sync successful" || Log.Info "ERROR ON DATABASE SYNC"
}
Database.Transaction() {
  Database.Query "
 PRAGMA FOREIGN_KEYS = ON;
 PRAGMA SYNCHRONOUS = NORMAL;
 PRAGMA CACHE_SIZE = 8192;
 PRAGMA TEMP_STORE = MEMORY;
 BEGIN TRANSACTION;
 ${*}
 COMMIT;
 PRAGMA OPTIMIZE" 2>&1 | sed '1,5d; $d'
}
Log.Critical() {
  local log
  log="[$(System.GetTime)][${FUNCNAME[1]}] CRITICAL | ${*}"
  test -n "${logToSyslog}" &&
    logger -t "${appName}" -p "crit" "${log}"
  echo -e "${log}" 1>&2
}
Log.Debug() {
  if [[ -n "${VERBOSE}" ]]; then
    local log
    log="[$(System.GetTime)][${FUNCNAME[1]}] DEBUG | ${*}"
    test -n "${logToSyslog}" &&
      logger -t "${appName}" -p "debug" "${log}"
    test -n "${VERBOSE}" && echo -e "${log}" 1>&2
  fi
}
Log.Error() {
  local log
  log="[$(System.GetTime)][${FUNCNAME[1]}] ERROR | ${*}"
  test -n "${logToSyslog}" &&
    logger -t "${appName}" -p "err" "${log}"
  echo -e "${log}" 1>&2
}
Log.Fatal() {
  local log
  log="[$(System.GetTime)][${FUNCNAME[1]}] FATAL | ${*}"
  test -n "${logToSyslog}" &&
    logger -t "${appName}" -p "crit" "${log}"
  echo -e "${log}" 1>&2
  return 1
}
Log.Info() {
  local log
  log="[$(System.GetTime)][${FUNCNAME[1]}] INFO | ${*}"
  test -n "${logToSyslog}" &&
    logger -t "${appName}" -p "info" "${log}"
  echo -e "${log}"
}
Log.Verbose() {
  if [[ -n "${VERBOSE}" ]]; then
    local log
    log="[$(System.GetTime)][${FUNCNAME[1]}] VERBOSE | ${*}"
    test -n "${logToSyslog}" &&
      logger -t "${appName}" -p "debug" "${log}"
    test -n "${VERBOSE}" && echo -e "${log}" 1>&2
  fi
}
Log.Warning() {
  local log
  log="[$(System.GetTime)][${FUNCNAME[1]}] WARNING | ${*}"
  test -n "${logToSyslog}" &&
    logger -t "${appName}" -p "warning" "${log}"
  echo -e "${log}" 1>&2
}
Log.ToSyslog() {
  local log
  log="[$(System.GetTime)][${FUNCNAME[1]}] INFO | ${*}"
  test -n "${logToSyslog}" &&
    logger -t "${appName}" -p "info" "${log}"
}
Log::Log.ToFile() {
  local log
  log="[$(System.GetTime)][${FUNCNAME[1]}] INFO | ${*}"
  test -n "${logToFile}" &&
    echo -e "${log}" >>"${logFile}"
}
Log.Check() { # Check if loglevel is exist.
  local loglevel
  loglevel=${1}
  case ${loglevel} in
  "alert" | "crit" | "debug" | "emerg" | "err" | "error" | "info" | "notice" | "warning")
    Log.ToSyslog "${loglevel}" "${*}"
    ;;
  *)
    false
    ;;
  esac
}

Log.ToEmergency() {
  local sLogLevel sMessage
  sLogLevel='emerg'
  sMessage=${*}
  test -n "${bLibLogToFile}" && Log.ToFile "${sLogLevel}" "${sMessage}"
  test -n "${bLibLogToSyslog}" && Log.ToSyslog "${sLogLevel}" "${sMessage}"
  test -n "${bLibLogToConsole}" && Log.ToConsole "${sLogLevel}" "${sMessage}"
}

Payload.BinaryEncode() {
  true
}
Proxmox.AddNodes() {
  local uris query
  uris=${1}
  for uri in "${uris[@]}"; do
    local protocol username hostname port sshEncodedPrivateKey sshEncodedPublicKey
    read -r protocol username hostname port <<<"$(tr ':/@' ' ' <<<"${uri}")"
    Test.VarsIsNotEmpty "${protocol}" "${username}" "${hostname}" "${port}"
    case $? in
    1)
      Log.Error "Error on add node ${uri} please enter valid URI syntax ex: sh://root@127.0.0.1:22"
      return 1
      ;;
    *)
      Log.Error "Unknown error on add node ${uri}"
      ;;
    esac
    sshEncodedPrivateKey=$(Crypto.GenerateEncodedSshPrivateKey)
    sshEncodedPublicKey=$(Crypto.GenerateEncodedSshPublicKey "${sshEncodedPrivateKey}")
    echo "PrivateKey: $(Crypto.DecodeStream <<<"${sshEncodedPrivateKey}")"
    echo "PublicKey: $(Crypto.DecodeStream <<<"${sshEncodedPublicKey}")"
    ssh -p "${port}" "${username}"@"${hostname}" "echo $(Crypto.DecodeStream <<<"${sshEncodedPublicKey}")" >>"${HOME}/.ssh/authorized_keys"
    case $? in
    0)
      Log.Info "Add node ${hostname} successful"
      query+="INSERT INTO ValhallaNodes (type, protocol, username, hostname, port) VALUES ('proxmox','${protocol}','${username}','${hostname}','${port}');"
      query+="INSERT INTO ValhallaNodesConnectionKey (hostname, key)
 VALUES ('${hostname}','${sshEncodedPrivateKey}');"
      ;;
    *)
      Log.Error "Error on add node ${hostname} please enter valid URI syntax ex: sh://root@127.0.0.1:22"
      return 1
      ;;
    esac
  done
  Database.Transaction "${query}" && Log.Info "Add nodes successful" || Log.Error "Error on add nodes please enter valid URI syntax ex: ssh://root@127.0.0.1:22"
}
Proxmox.GetNodeKey() {
  local hostname
  hostname=${1}
  Test.VarsIsNotEmpty "${hostname}" && Crypto.DecodeStream <<<$(Database.Query "SELECT key FROM ValhallaNodesConnectionKey WHERE hostname='${hostname}';")
}
Proxmox.GetNodes() {
  Database.Query "SELECT FROM ValhallaNodes WHERE type='proxmox';"
}
Proxmox.GetNodesAddresses() {
  Database.Query "SELECT address FROM ValhallaNodes WHERE type='proxmox';"
}
Proxmox.GetNodesHostnames() {
  Database.Query "SELECT hostname FROM ValhallaNodes WHERE type='proxmox';"
}
Proxmox.NodeStatus() {
  local hostname status
  hostname=${1}
  status=$(Proxmox.NodeStatusRaw "${hostname}")
  case ${status} in
  0)
    Log.Info "Node ${hostname} is running"
    ;;
  1)
    Log.Info "Node ${hostname} is stopped"
    ;;
  2)
    Log.Info "Node ${hostname} is unknown"
    ;;
  *)
    Log.Info "Node ${hostname} is not reachable"
    ;;
  esac
}
Proxmox.NodeStatusRaw() {
  local hostname address port username protocol
  hostname=${1}
  address=$(Database.Query "SELECT address FROM ValhallaNodes WHERE hostname='${hostname}';")
  port=$(Database.Query "SELECT port FROM ValhallaNodes WHERE hostname='${hostname}';")
  username=$(Database.Query "SELECT username FROM ValhallaNodes WHERE hostname='${hostname}';")
  protocol=$(Database.Query "SELECT protocol FROM ValhallaNodes WHERE hostname='${hostname}';")
  case ${protocol} in
  ssh)
    ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no -p "${port}" "${username}"@"${address}" "echo 0"
    ;;
  *)
    Log.Error "Protocol ${protocol} not supported"
    ;;
  esac
}
Proxmox.RemoveNodes() {
  local hostnames=("$@")
  local query=""
  for hostname in "${hostnames[@]}"; do
    query+="DELETE FROM ValhallaNodes WHERE hostname='${hostname}';"
  done
  Database.Transaction "${query}" && Log.Info "Remove nodes successful" || Log.Error "ERROR ON REMOVE NODES"
}
Proxmox.SetSshPrivateKey() {
  local hostname sshPrivateKey
  hostname=${1}
  sshPrivateKey=${2}
  Database.Query "UPDATE ValhallaNodes SET password='${sshPrivateKey}' WHERE hostname='${hostname}';" || Log.Error "Error on set ssh private key"
}
System.FreeMemory() {
  free --mega | awk 'NR==2{printf "%.2f", $4}'
}
System.GetArch() {
  uname --machine
}
System.GetBinaryPath() {
  command -v "${1}" && Log.PrintDebug "Binary \"${1}\" found in path." || Log.Error "Binary \"${1}\" not found in path."
}
System.GetDate() {
  date --iso-8601=ns
}
System.GetHostname() {
  uname --nodename
}
System.GetKernelName() {
  uname --kernel-name
}
System.GetKernelRelease() {
  uname --kernel-release
}
System.GetKernelVersion() {
  uname --kernel-version
}
System.GetMachineHardwarePlatform() {
  uname --hardware-platform
}
System.GetOS() {
  uname --kernel-name
}
System.GetOperatingSystem() {
  uname --operating-system
}
System.GetTime() {
  date --iso-8601=ns
}
System.GetTimestamp() {
  date +%s
}
System.Initialize() {
  dateBinary=$(command -v date) || Logging.PrintErrorAndExit "Date not found in path."
  freeBinary=$(command -v free) || Logging.PrintErrorAndExit "Free not found in path."
  syncBinary=$(command -v sync) || Logging.PrintErrorAndExit "Sync not found in path."
  unameBinary=$(command -v uname) || Logging.PrintErrorAndExit "Uname not found in path."
}
System.Run() {
  eval "${*}"
  returnCode=${?}
}
System.Sync() {
  Logging.PrintVerbose "Preparing to sync."
  if sync; then
    Logging.PrintVerbose "Sync successful."
  else
    Logging.PrintError "Sync failed."
    return 1
  fi
}
System.SyncFile() {
  Logging.PrintVerbose "Prepare to sync file: \"${1}\" on disk."
  if sync --data "${1}"; then
    Logging.PrintVerbose "Sync successful."
  else
    Logging.PrintError "Sync failed."
    return 1
  fi
}
System.SyncFileSystem() {
  Logging.PrintVerbose "Prepare to sync filesystem: \"${1}\" on disk."
  if sync --file-system "${1}"; then
    Logging.PrintVerbose "Sync successful."
  else
    Logging.PrintError "Sync failed."
    return 1
  fi
}

Test.FilesExist() {
  for file in "${@}"; do
    test -e "${file}"
    case $? in
    0)
      Log.Debug "File: \"${file}\" exists."
      ;;
    2)
      Log.Error "File: \"${file}\" does not exist."
      return 1
      ;;
    *)
      Log.Error "Undetermined error: \nfunction: \"${FUNCNAME[0]}\"\ninput: \"${*}\""
      return 1
      ;;
    esac
  done
}

Test.FileIsBlock() {
  if test -b "${1}"; then
    Log.Verbose "File: \"${1}\" is block."
  else
    Log.Error "File: \"${1}\" is not block."
    return 1
  fi
}
Test.FileIsChar() {
  if test -c "${1}"; then
    Log.Verbose "File: \"${1}\" is char."
  else
    Log.Error "File: \"${1}\" is not char."
    return 1
  fi
}
Test.FileIsDir() {
  if test -d "${1}"; then
    Log.Verbose "File: \"${1}\" is dir."
  else
    Log.Error "File: \"${1}\" is not dir."
    return 1
  fi
}
Test.FileIsExec() {
  if test -x "${1}"; then
    Log.Verbose "File: \"${1}\" is exec."
  else
    Log.Error "File: \"${1}\" is not exec."
    return 1
  fi
}
Test.FileIsExist() {
  if test -e "${1}"; then
    Log.Verbose "File: \"${1}\" is exist."
  else
    Log.Error "File: \"${1}\" is not exist."
    return 1
  fi
}
Test.FileIsFifo() {
  if test -p "${1}"; then
    Log.Verbose "File: \"${1}\" is fifo."
  else
    Log.Error "File: \"${1}\" is not fifo."
    return 1
  fi
}
Test.FileIsLink() {
  if test -L "${1}"; then
    Log.Verbose "File: \"${1}\" is link."
  else
    Log.Error "File: \"${1}\" is not link."
    return 1
  fi
}
Test.FileIsNotNull() {
  if test -s "${1}"; then
    Log.Verbose "File: \"${1}\" is not null."
  else
    Log.Error "File: \"${1}\" is null."
    return 1
  fi
}
Test.FileIsRead() {
  if test -r "${1}"; then
    Log.Verbose "File: \"${1}\" is read."
  else
    Log.Error "File: \"${1}\" is not readable."
    return 1
  fi
}
Test.FileIsReadAndWrite() {
  Test.FileIsExist "${1}" && Test.FileIsRead "${1}" && Test.FileIsWrite "${1}"
}
Test.FileIsReadAndWriteAndExecutable() {
  Test.FileIsExist "${1}" && Test.FileIsRead "${1}" && Test.FileIsWrite "${1}" && Test.FileIsExec "${1}"
}
Test.FileIsReadAndWriteAndNotNull() {
  Test.FileIsExist "${1}" && Test.FileIsRead "${1}" && Test.FileIsWrite "${1}" && Test.FileIsNotNull "${1}"
}
Test.FileIsSocket() {
  if test -S "${1}"; then
    Log.Verbose "File: \"${1}\" is socket."
  else
    Log.Error "File: \"${1}\" is not socket."
    return 1
  fi
}
Test.FileIsWrite() {
  if test -w "${1}"; then
    Log.Verbose "File: \"${1}\" is write."
  else
    Log.Error "File: \"${1}\" is not writable."
    return 1
  fi
}
Test.VarsIsNotEmpty() {
  for var in "${@}"; do
    if test -z "${var}"; then
      Log.Error "Input: is empty."
      return 1
    else
      Log.Verbose "Is not empty content: \"${var}\"."
    fi
  done
}
Utils.GetFileHash() {
  hashAlgorithm="${2:-blake2b512}"
  test -n "${hashAlgorithm}" && Logging.PrintVerbose "Hash algorithm specified : ${hashAlgorithm}"
  test -n "${1}" || Logging.PrintError "File not specified."
  test -f "${1}" || Logging.PrintError "File not existing."
  test -r "${1}" || Logging.PrintError "File is not readable."
  test -n "$(Utils.GetHashAlgorithm | grep -E "${hashAlgorithm}")" || Logging.PrintError "Hash algorithm not supported."
  openssl dgst -"${hashAlgorithm}" -r "${1}" | cut --delimiter=' ' --fields=1
}
Utils.SortAndDeduplicate() {
  sort -u
}
Utils.SortAndDeduplicateAndRemoveEmptyLines() {
  Utils.SortAndDeduplicate | sed '/^$/d'
}
