#!/system/bin/sh
# App Data Keeper Daemon (adkd) Starter
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL V3+


(modPath=${0%/*}
logFile=/data/media/adk/logs/main.log


set -euo pipefail
umask 000


# wait until /data is decrypted
until [ -e /data/media/0/Android ]; do sleep 5; done


# log
mkdir -p ${logFile%/*}
[ -f $logFile ] && mv $logFile $logFile.old
exec 1>>$logFile 2>&1
set -x

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

. $modPath/core.sh
backupd &) &
