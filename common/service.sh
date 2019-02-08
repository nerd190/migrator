#!/system/bin/sh
# Migrator Auto-start Script
# Copyright (C) 2018-2019, VR25 @ xda-developers
# License: GPL V3+

(modPath=${0%/*}
log=/data/media/migrator/logs/boot.log

umask 0
set -euo pipefail

# wait until /data is decrypted
until [ -d /data/media/0/?ndroid ]; do sleep 10; done

# log
mkdir -p ${log%/*}
[ -f $log ] && grep -q .. $log && mv $log $log.old
exec 1>$log 2>&1
if [ -f /data/media/migrator/verbose ]; then
  rm /data/media/migrator/verbose
  set -x
fi

. $modPath/core.sh
onboot &) &
