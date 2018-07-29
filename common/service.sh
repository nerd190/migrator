#!/system/bin/sh
# App Data Keeper (adk) APK Backup'er
# (c) 2018, VR25 @ xda-developers
# License: GPL v3+


main() {
  # verbose engine
  logsDir=/data/media/adk/logs
  newLog=$logsDir/bkp_apks_verbose_log.txt
  oldLog=$logsDir/bkp_apks_verbose_previous_log.txt
  [[ -d $logsDir ]] || mkdir -p -m 777 $logsDir
  [[ -f $newLog ]] && mv $newLog $oldLog
  set -x 2>>$newLog

  modPath=${0%/*}
  . $modPath/adk.sh
  bkp_apks
}

(main) &
