#!/system/bin/sh
# App Data Keeper (adk) main() Caller
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


main_() {

  modId=adk
  modData=/data/media/$modId
  Config=$modData/config.txt
  appData=$modData/appdata
  Function=main
  logsDir=$modData/logs
  newLog=$logsDir/${Function}.log
  oldLog=$logsDir/${Function}_old.log
  pkgList=/data/system/packages.list
  magiskDir=/data/adb/magisk
  utilFunc=$magiskDir/util_functions.sh
  modPath=$(sed -n 's/^.*MOUNTPATH=//p' $utilFunc | head -n1)/$modId

  set -u # exit on unset or null variable/parameter
  setenforce 0 # sets SELinux mode to "permissive"
  umask 000 # default perms (d=rwx-rwx-rwx, f=rw-rw-rw)

  pkg_name() { echo "$Line" | awk '{print $1}'; }
  data_owner() { echo "$Line" | awk '{print $2}'; }

  restore_data() {
    # if $appData is not empty
    if [ -n "$(ls "$appData" 2>/dev/null)" ]; then
      awk '{print $1,$2}' $pkgList | \
        while read Line; do
          (if [ -n "$(ls "$appData/$(pkg_name)")" ]; then
            rm -rf "/data/data/$(pkg_name)"
            mv "$appData/$(pkg_name)" /data/data/
            chown -R "$(data_owner):$(data_owner)" "/data/data/$(pkg_name)"
          fi 2>/dev/null) &
        done
      wait # for background jobs to finish
    fi
  }

  # log engine
  if [ ! -f $modPath/disable ]; then
    mkdir -p $logsDir 2>/dev/null
    [ -f "$newLog" ] && mv $newLog $oldLog
    set +u
    [ -n $EPOCHREALTIME ] && PS4='[$EPOCHREALTIME] '
    set -u
    exec &>>$newLog
    set -x
  fi

  # data restore & $0 self-destruction
  if [ -f $modPath/disable ] || [ ! -f $modPath/module.prop ] \
    || ! grep -q '^inc' $Config 2>/dev/null
  then
    grep -q '^lite' $Config 2>/dev/null || restore_data
    [ -f $modPath/module.prop ] || rm $0
    exit 0
  fi

  . $modPath/core.sh
  grep -q '^lite' $Config 2>/dev/null || $Function
  backups
}

(main_) &
