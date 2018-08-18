#!/system/bin/sh
# App Data Keeper (adk) main() Caller
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


setenforce 0
umask 000
set -u

modID=adk
modData=/data/media/$modID
config=$modData/config.txt
appData=$modData/.appData
functionName=main
logsDir=$modData/logs
newLog=$logsDir/${functionName}.log
oldLog=$logsDir/${functionName}_old.log
pkgList=/data/system/packages.list


modPath=/sbin/.core/img/$modID
[ -f $modPath/module.prop ] || modPath=/magisk/$modID


pkg_name() { echo $LINE | awk '{print $1}'; }
data_owner() { echo $LINE | awk '{print $2}'; }


restore_data() {
  if [ -n "$(ls "$appData" 2>/dev/null)" ]; then # if $appData is not empty
    awk '{print $1,$2}' $pkgList | \
      while read line; do # while read pkg_name and ownership
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
mkdir -p $logsDir 2>/dev/null
[ -f "$newLog" ] && mv $newLog $oldLog
set -x 2>>$newLog

# if $modID is not installed, restore data, then cleanup & self-destruct
if [ ! -f $modPath/module.prop ]; then
  restore_data
  mv -f $newLog /sdcard/$modID.log
  { mv -f $config /sdcard/${modID}_config_bkp.txt
  rm -rf $modData; } 2>/dev/null
  rm $0
  exit 0
fi

# restore data if $modID is disabled
if [ -f $modPath/disable ]; then
  restore_data
  exit 0
fi

. $modPath/core.sh
$functionName
exit 0
