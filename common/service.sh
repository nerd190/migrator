#!/system/bin/sh
# service.sh, post-fs-data.sh
# Migrator Auto-start Script
# Copyright (C) 2018-2019, VR25 @ xda-developers
# License: GPL V3+

(modPath=${0%/*}
tmpDir=/dev/migrator
modData=/data/media/migrator
log=/data/media/migrator/logs/boot.log

umask 0
set -euo pipefail

# don't run more than once per boot session
[ -d $tmpDir ] && exit 0 || mkdir -p $tmpDir

# wait until /data is decrypted
until [ -d /data/media/0/?ndroid ]; do sleep 10; done

# log
mkdir -p ${log%/*}
[ -f $log ] && grep -q .. $log && mv $log $log.old
exec 1>$log 2>&1
if [ -f $modData/verbose ] || [ -d $modData/migrated_data ]; then
  rm $modData/verbose 2>/dev/null || :
  set -x
fi

. $modPath/core.sh
onboot &) &
