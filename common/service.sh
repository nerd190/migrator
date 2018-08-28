#!/system/bin/sh
# App Data Keeper (adk) App+Data Backup Daemon Starter
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


main() {

  modId=adk
  modPath=${0%/*}
  Function=backups
  modData=/data/media/$modId
  logsDir=$modData/logs
  newLog=$logsDir/${Function}.log
  oldLog=$logsDir/${Function}_old.log

  set -u # exit on unset or null variable/parameter
  setenforce 0 # sets SELinux mode to "permissive"
  umask 000 # default perms (d=rwx-rwx-rwx, f=rw-rw-rw)

  # verbose generator
  mkdir -p $logsDir 2>/dev/null
  [ -f "$newLog" ] && mv $newLog $oldLog
  exec &>>$newLog
  set -x

  . $modPath/core.sh
  $Function
}

(main) &
