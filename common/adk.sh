#!/system/bin/sh
# App Data Keeper (adk) main() Caller
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


setenforce 0
set -u

modID=adk
modData=/data/media/$modID
config=$modData/config.txt
appData=$modData/.appData
functionName=main
logsDir=$modData/logs
newLog=$logsDir/${functionName}.log
oldLog=$logsDir/${functionName}_old.log

modPath=/sbin/.core/img/$modID
[ -f $modPath/module.prop ] || modPath=/magisk/$modID

restore_data() {
  for line in $(ls $appData); do
    (rm -rf "/data/data/$line" 2>/dev/null
    mv "$appData/$line" /data/data/) &
  done
  wait
  rmdir $appData
}

# verbose generator
mkdir -p $logsDir 2>/dev/null
[ -f "$newLog" ] && mv $newLog $oldLog
set -x 2>>$newLog

# if $modID is not installed, restore data, then cleanup & self-destruct
if [ ! -f $modPath/module.prop ]; then
  restore_data
  mv -f $newLog /sdcard/$modID.log
  { mv -f $config /sdcard/${modID}_config_bkp.log
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
wait
exit 0
