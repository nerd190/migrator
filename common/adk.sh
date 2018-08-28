#!/system/bin/sh
# App Data Keeper (adk) main() Caller
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


modId=adk
modData=/data/media/$modId
Config=$modData/config.txt
appData=$modData/appdata
Function=main
logsDir=$modData/logs
newLog=$logsDir/${Function}.log
oldLog=$logsDir/${Function}_old.log
pkgList=/data/system/packages.list
modPath="$(sed -n 's/^.*MOUNTPATH=//p' /data/adb/magisk/util_functions.sh)/$modId"


set -u # exit on unset or null variable/parameter
setenforce 0 # sets SELinux mode to "permissive"
umask 000 # default perms (d=rwx-rwx-rwx, f=rw-rw-rw)


pkg_name() { echo "$LINE" | awk '{print $1}'; }
data_owner() { echo "$LINE" | awk '{print $2}'; }


restore_data() {
  # if $appData is not empty
  if [ -n "$(ls "$appData" 2>/dev/null)" ]; then
    awk '{print $1,$2}' $pkgList | \
      while read line; do
        (LINE=$line
        if [ -n "$(ls "$appData/$(pkg_name)")" ]; then
          rm -rf "/data/data/$(pkg_name)"
          mv "$appData/$(pkg_name)" /data/data/
          chown -R "$(data_owner):$(data_owner)" "/data/data/$(pkg_name)"
        fi 2>/dev/null) &
      done
    wait # for background jobs to finish
  fi
}


# verbose generator
if [ ! -f $modPath/disable ]; then
  mkdir -p $logsDir 2>/dev/null
  [ -f "$newLog" ] && mv $newLog $oldLog
  exec &>>$newLog
  set -x
fi


# data restore & $0 self-destruction
if [ -f $modPath/disable ] || [ ! -f $modPath/module.prop ] \
  || ! grep -q '^inc' $Config 2>/dev/null
then
  restore_data
  [ -f $modPath/module.prop ] || rm $0
  exit 0
fi


. $modPath/core.sh
$Function
exit 0
