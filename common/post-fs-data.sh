#!/system/bin/sh
# App Data Keeper (adk) main() Caller
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


set -u

modID=adk
modPath=${0%/*}
functionName=main
modData=/data/media/$modID
logsDir=$modData/logs
newLog=$logsDir/${functionName}_verbose_log.txt
oldLog=$logsDir/${functionName}_verbose_previous_log.txt

# verbose generator
mkdir -p $logsDir 2>/dev/null
[ -f "$newLog" ] && mv $newLog $oldLog
set -x 2>>$newLog

. $modPath/core.sh
$functionName
wait
exit 0
