# App Data Keeper (adk) core
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


modId=adk
modData=/data/media/$modId
Config=$modData/config.txt
defaultConfig=$modPath/default_config.txt
migratedData=$modData/migrated_data
apkBkps=$modData/backups/apk
pkgList=/data/system/packages.list # installed packages
appDataBkps=$modData/backups/appdata
tmpDir=/dev/adk_tmp
rsync=$modPath/bin/rsync
failedRes=$modData/failed_restores
i=/sdcard # internal media storage


# app data backup frequency (in hours)
bkpFreq=$(sed -n 's/^bkpFreq=//p' "$Config" 2>/dev/null || true)
[ -z "$bkpFreq" ] && bkpFreq=8 # fallback


# preparation
mkdir -p $tmpDir
[ -f "$Config" ] || cp $defaultConfig $Config


# wait 90 seconds for external storage ($e)
# If multiple partitions are found, the largest is used for backups
find_sdcard() {
  local Count=0 Size=0 newSize=0
  set +u
  if [ "$1" != "nowait" ]; then
    set -u
    wait_booted
    until [ "$Count" -ge "360" ]; do
      ((Count++)) || true
      grep -q '/mnt/media_rw' /proc/mounts && break || sleep 4
    done
  fi
  set -u
  if grep -q '/mnt/media_rw' /proc/mounts; then
    # wait for additional partitions to be mounted
    set +u
    [ "$1" = "nowait" ] || sleep 4
    set -u
    for e in /mnt/media_rw/*; do # $e=<external storage>
      newSize=$(df "$e" | tail -n 1 | awk '{print $2}')
      if [ "$newSize" -gt "$Size" ]; then
        Size=$newSize
        apkBkps="$e/adk/backups/apk"
        appDataBkps="$e/adk/backups/appdata"
      fi
    done
  fi
}


# backup APKs
# defaultStorage=external ($e)
# fallBackStorage=internal ($i)
bkp_apps() {
  local Pkg="" pkgName=""
  mkdir -p "$apkBkps" "$appDataBkps"
  for Pkg in $(find /data/app -type f -name base.apk); do
    pkgName=$(dirname $Pkg | sed 's:/data/app/::; s:-.*::')
    if { grep -q '^inc$' $Config || match_test inc $pkgName; } \
      && ! match_test exc $pkgName
    then
      $rsync -tu --inplace $Pkg "$apkBkps/$pkgName.apk"
    fi
  done
}


# incremental apps data backup
bkp_appdata() {
  local Pkg=""
  while true; do
    for Pkg in $(awk '{print $1}' $pkgList); do
      if ! ls -p /data/app/$Pkg* 2>/dev/null | grep -q /; then
        if match_test inc $Pkg; then
          $rsync -Drtu --del \
            --exclude=cache --exclude=code_cache \
            --exclude=app_webview/GPUCache \
            --inplace /data/data/$Pkg "$appDataBkps" >/dev/null 2>&1 || true
          bkp_symlinks
        fi
      else
        if { grep -q '^inc$' $Config || match_test inc $Pkg; } \
          && ! match_test exc $Pkg
        then
          $rsync -Drtu --del \
            --exclude=cache --exclude=code_cache \
            --exclude=app_webview/GPUCache \
            --inplace /data/data/$Pkg "$appDataBkps" >/dev/null 2>&1 || true
          bkp_symlinks
        fi
      fi
    done
    set +u
    [ "$1" = ondemand ] && break || sleep $((bkpFreq * 3600))
    set -u
  done
}


# pseudo-daemon
backupd() {
  set +u
  if [ "$1" != ondemand ]; then
    set -u
    restore_on_boot
    retry_failed_restores
    find_sdcard
    bkp_apps
    (bkp_appdata) &
  else
    set -u
    find_sdcard nowait
    echo -n "(i) Backing up APKs..."
    bkp_apps
    echo -en "\n(i) Backing up apps data..."
    bkp_appdata $1
  fi
  if grep -q '^bkp ' $Config; then
    set +u
    [ "$1" = ondemand ] && echo -en "\n(i) Backing up misc data..."
    set -u
    while true; do
      sed -n "s:^bkp:$rsync -rtu --inplace:p" \
        $Config >$tmpDir/backupd
      source $tmpDir/backupd
      set +u
      # the extra hour prevents conflicts with bkp_appdata()
      [ "$1" = ondemand ] && break || sleep $((bkpFreq * 3600 + 3600))
      set -u
    done
  fi
  set +u
  [ "$1" = ondemand ] && echo; echo; exit_or_not
  wait
}


bkp_symlinks() {
  local l="" lns="$appDataBkps/$Pkg.lns"
  : >"$lns"
  for l in $(find /data/data/$Pkg -type l); do
    echo "$(readlink -f $l | sed "s:$Pkg.*/lib/[^/]*:$Pkg\*/lib/\*:; s:$Pkg.*/lib/:$Pkg\*/lib/:") $l" >>$lns
  done
  grep -q '^/' "$lns" || rm "$lns"
}


restore_symlinks() {
  local l=""
  if [ -f "$1" ]; then
    cat "$1" | \
      while read l; do
        eval ln -fs $l 2>/dev/null || true
      done
  fi
}


restore_on_boot() {
  local Pkg="" o=""
  if ls -p $migratedData 2>/dev/null | grep -q / \
    && ! grep -q '^noauto' $Config
  then
    set +eo pipefail
    wait_booted
    for Pkg in $(ls -1p $migratedData | grep / | tr -d /); do
      if grep -q $Pkg $pkgList; then
        [ -f $migratedData/$Pkg.apk ] \
          && pm install -r $migratedData/$Pkg.apk 1>/dev/null \
          && rm $migratedData/$Pkg.apk
      else
        [ -f $migratedData/$Pkg.apk ] \
          && pm install $migratedData/$Pkg.apk 1>/dev/null \
          && rm $migratedData/$Pkg.apk
      fi
      if grep -q $Pkg $pkgList; then
        pm disable $Pkg 1>/dev/null
        rm -rf /data/data/$Pkg
        mv $migratedData/$Pkg /data/data/
        restore_symlinks $migratedData/$Pkg.lns
        rm $migratedData/$Pkg.lns
        o=$(grep "$Pkg" "$pkgList" | awk '{print $2}')
        chown -R $o:$o /data/data/$Pkg 2>/dev/null
        pm enable $Pkg 1>/dev/null
      else
        mkdir -p $failedRes
        grep $Pkg $logFile >$failedRes/$Pkg.log
        mv $migratedData/$Pkg* $failedRes/
      fi
    done
    rm -rf $migratedData
    set -eo pipefail
  fi
}


# wait until system has fully booted
wait_booted() {
  until [ "$(getprop init.svc.bootanim)" = stopped ] \
    && grep -q /storage/emulated /proc/mounts; do sleep 5; done
}


retry_failed_restores() {
  local c=""
  for c in 1 2 3; do # 3 times
    if mv $failedRes $migratedData 2>/dev/null; then
      restore_on_boot
    else
      break
    fi
  done
}


#$1="inc or exc"
#$2=pkgName
match_test() {
  local p=""
  for p in $(sed -n "s/^$1 //p" $Config); do
    echo $2 | grep -Eq "$p" 2>/dev/null && return 0 || true
  done
  return 1
}
