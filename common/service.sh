#!/system/bin/sh
# App Data Keeper (adk) backupd starter
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


# shell behavior
set -o errexit # set -e
set -o nounset # set -u
set -o pipefail
#set -o xtrace # set -x
#IFS=$'\n\t' # new line & tab
umask 000 # default perms (d=rwx-rwx-rwx, f=rw-rw-rw)


main() {

  modId=adk
  modPath=${0%/*}
  modData=/data/media/$modId
  logsDir=$modData/logs
  logFile=$logsDir/main.log
  oldLog=$logFile.old

  # log engine
  mkdir -p $logsDir
  [ -f "$logFile" ] && mv $logFile $oldLog
  set +u
  [ -n "$EPOCHREALTIME" ] && PS4='[$EPOCHREALTIME] '
  set -u
  exec &>>$logFile
  set -o xtrace # set -x

  # exit trap (debugging tool)
  debug_exit() {
    echo -e "\n***EXIT $?***\n"
    set +euxo pipefail
    getprop | grep -Ei 'product|version'
    echo
    set
    echo
    echo "SELinux status: $(getenforce 2>/dev/null || sestatus 2>/dev/null)" \
      | sed 's/En/en/;s/Pe/pe/'
  }
  trap debug_exit EXIT

  source $modPath/core.sh # load core
  backupd # pseudo-daemon
}

(main) &
