#!/system/bin/sh
# App Data Keeper (adk) main() Caller
# (c) 2018, VR25 @ xda-developers
# License: GPL v3+


modID=adk
modPath=${0%/*}
functionName=main
modData=/data/media/$modID

# verbosity engine
logsDir=$modData/logs
newLog=$logsDir/${functionName}_verbose_log.txt
oldLog=$logsDir/${functionName}_verbose_previous_log.txt
[[ -d $logsDir ]] || mkdir -p $logsDir
[[ -f $newLog ]] && mv $newLog $oldLog
set -x 2>>$newLog

. $modPath/core.sh
$functionName
