#!/system/bin/sh
# App Data Keeper (adk) APK Backup'er
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


main() {

  set -u
  umask 000

  modID=adk
  modPath=${0%/*}
  functionName=bkp_apps
  modData=/data/media/$modID
  logsDir=$modData/logs
  newLog=$logsDir/${functionName}.log
  oldLog=$logsDir/${functionName}_old.log

  # verbose generator
  mkdir -p $logsDir 2>/dev/null
  [ -f "$newLog" ] && mv $newLog $oldLog
  set -x 2>>$newLog

  . $modPath/core.sh
  ($functionName) &
  pending_apps
  wait
  exit 0
}

(main) &
