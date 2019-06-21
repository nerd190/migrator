#!/system/bin/sh
# post-fs-data.sh, service.sh
# Migrator auto-start script
# Copyright (C) 2018-2019, VR25 @ xda-developers
# License: GPL V3+


(modPath=${0%/*}
tmpDir=/dev/migrator
log=$tmpDir/boot.log
modData=/data/media/migrator


get_value() {
  sed -n "s|^$1=||p" $modData/config.txt \
    | sed -e 's/#.*//' -e 's/ $//' -e 's/ $//' -e 's/ $//'
}


umask 0
set -euo pipefail


# don't run more than once per boot session
if [ -d $tmpDir ]; then
  exit 0
else
  mkdir -p $tmpDir
  mount -t tmpfs -o size=10M tmpfs $tmpDir
fi


# wait for storage, boot_completed, package manager, and decryption

until [ -d /storage/emulated/0/?ndroid ] \
  && [[ "x$(getprop sys.boot_completed)" == x[1t]* ]] \
  && pm get-install-location 1>/dev/null 2>&1
do
  sleep 20
done

# FBE-decryption and stability evaluation timeout
sleep $(( $(get_value autoRestoreDelayM) * 60 )) 2>/dev/null \
  || sleep 300 # 5 minutes (default)


# verbose
exec 1>$log 2>&1
set -x


. $modPath/core.sh
onboot &) &
