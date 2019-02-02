# Migrator Core
# Copyright (C) 2018-2019, VR25 @ xda-developers
# License: GPL V3+


modId=adk
modData=/data/media/$modId
config=$modData/config.txt
defaultConfig=$modPath/default_config.txt
migratedData=$modData/migrated_data
apkBkps=$modData/backups/apk
pkgList=/data/system/packages.list # installed packages
appDataBkps=$modData/backups/appdata
tmpDir=/dev/$modId
rsync=$modPath/bin/rsync
failedRes=$modData/failed_restores
i=/sdcard # internal media storage


# preparation
mkdir -p $tmpDir
touch $modData/.nomedia
[ -f $config ] || cp $defaultConfig $config


# incremental backup frequency (in hours)
bkpFreq=$(sed -n 's/^bkpFreq=//p' $config)


# wait for external storage ($e)
# if multiple partitions are found, the largest is used for backups
find_sdcard() {
  local count=0 size=0 newSize=0
  set +u
  if [ "x$1" != xnowait ]; then
    set -u
    wait_booted
    until [ $count -ge 1800 ]; do
      count=$((count + 10)) || :
      grep -q /mnt/media_rw /proc/mounts && break || sleep 10
    done
  fi
  set -u
  if grep -q /mnt/media_rw /proc/mounts; then
    # wait for additional partitions to be mounted
    set +u
    [ "x$1" = xnowait ] || sleep 10
    set -u
    for e in /mnt/media_rw/*; do # $e=<external storage>
      newSize=$(df "$e" | tail -n 1 | awk '{print $2}')
      if [ $newSize -gt $size ]; then
        size=$newSize
        apkBkps="$e/$modId/backups/apk"
        appDataBkps="$e/$modId/backups/appdata"
        mkdir -p "$apkBkps" "$appDataBkps"
        touch "$e/$modId/.nomedia"
      fi
    done
  fi
}


# backup APKs
# defaultStorage=external ($e)
# fallBackStorage=internal ($i)
bkp_apps() {
  local pkg="" pkgName=""
  mkdir -p "$apkBkps" "$appDataBkps"
  for pkg in $(find /data/app -type f -name base.apk); do
    pkgName=$(dirname $pkg | sed 's:/data/app/::; s:-.*::')
    if { grep -q '^inc$' $config || match_test inc $pkgName; } \
      && ! match_test exc $pkgName \
      && ! grep $pkg /data/system/packages.xml | grep -q '/system/.*app/'
    then
      $rsync -tu --inplace $pkg "$apkBkps/$pkgName.apk"
    fi
  done
}


# incremental apps data backup
bkp_appdata() {
  local pkg=""
  while true; do
    for pkg in $(awk '{print $1}' $pkgList); do
      if ! ls -p /data/app/$pkg* 2>/dev/null | grep -q /; then
        if match_test inc $pkg; then
          $rsync -Drtu --del \
            --exclude=cache --exclude=code_cache \
            --exclude=app_webview/GPUCache \
            --exclude=shared_prefs/com.google.android.gms.appid.xml \
            --inplace /data/data/$pkg "$appDataBkps" 1>/dev/null 2>&1 || :
          bkp_symlinks
        fi
      else
        if { grep -q '^inc$' $config || match_test inc $pkg; } \
          && ! match_test exc $pkg \
          && ! grep $pkg /data/system/packages.xml | grep -q '/system/.*app/'
        then
          $rsync -Drtu --del \
            --exclude=cache --exclude=code_cache \
            --exclude=app_webview/GPUCache \
            --exclude=shared_prefs/com.google.android.gms.appid.xml \
            --inplace /data/data/$pkg "$appDataBkps" >/dev/null 2>&1 || :
          bkp_symlinks
        fi
      fi
    done
    set +u
    [ "x$1" = xondemand ] && break || sleep $((bkpFreq * 3600))
    set -u
  done
}


onboot() {
  set +u
  if [ "x$1" != xondemand ]; then
    set -u
    restore_on_boot
    retry_failed_restores
    ! grep -iq nobkp $config || exit 0
    find_sdcard
    bkp_apps
    (bkp_appdata) &
  else
    set -u
    find_sdcard nowait
    echo -n "(i) Backing up apps.."
    bkp_apps
    echo -en "\n(i) Backing up data.."
    bkp_appdata $1
  fi
  if grep -q '^bkp ' $config; then
    set +u
    [ "x$1" = xondemand ] && echo -en "\n(i) Backing up misc data.."
    set -u
    while true; do
      sed -n "s:^bkp:$rsync -rtu --inplace:p" \
        $config >$tmpDir/onboot
      . $tmpDir/onboot
      set +u
      # the extra hour prevents conflicts with bkp_appdata()
      [ "x$1" = xondemand ] && break || sleep $((bkpFreq * 3600 + 3600))
      set -u
    done
  fi
  set +u
  [ "x$1" = xondemand ] && { echo; echo; exit_or_not; }
  wait
}


bkp_symlinks() {
  local l="" lns="$appDataBkps/$pkg.lns"
  : >"$lns"
  for l in $(find /data/data/$pkg -type l); do
    echo "$(readlink -f $l | sed "s:$pkg.*/lib/[^/]*:$pkg\*/lib/\*:; s:$pkg.*/lib/:$pkg\*/lib/:") $l" >>$lns
  done
  grep -q '^/' "$lns" || rm "$lns"
}


restore_symlinks() {
  local l=""
  if [ -f "$1" ]; then
    cat "$1" | \
      while read l; do
        eval ln -fs $l 2>/dev/null || :
      done
  fi
}


restore_on_boot() {
  local pkg="" o=""
  if ls -p $migratedData 2>/dev/null | grep -q / \
    && ! grep -iq '^noauto' $config
  then
    set +eo pipefail
    wait_booted
    for pkg in $(ls -1p $migratedData | grep / | tr -d /); do
      if grep -q $pkg $pkgList; then
        [ -f $migratedData/$pkg.apk ] \
          && pm install -r $migratedData/$pkg.apk 1>/dev/null \
          && rm $migratedData/$pkg.apk
      else
        [ -f $migratedData/$pkg.apk ] \
          && pm install $migratedData/$pkg.apk 1>/dev/null \
          && rm $migratedData/$pkg.apk
      fi
      if grep -q $pkg $pkgList; then
        pm disable $pkg 1>/dev/null
        rm -rf /data/data/$pkg
        mv $migratedData/$pkg /data/data/
        rm /data/data/$pkg/shared_prefs/com.google.android.gms.appid.xml 2>/dev/null
        restore_symlinks $migratedData/$pkg.lns
        rm $migratedData/$pkg.lns 2>/dev/null
        o=$(grep "$pkg" "$pkgList" | awk '{print $2}')
        chown -R $o:$o /data/data/$pkg 2>/dev/null
        pm enable $pkg 1>/dev/null
      else
        mkdir -p $failedRes
        grep $pkg $log >$failedRes/$pkg.log
        mv $migratedData/$pkg* $failedRes/
      fi
    done
    rm -rf $migratedData
    set -eo pipefail
  fi
}


# wait until system has fully booted
wait_booted() {
  until echo "x$(getprop sys.boot_completed)" | grep -Eq '1|true' \
    && grep -q /storage/emulated /proc/mounts; do sleep 10; done
}


retry_failed_restores() {
  local c=""
  for c in 1 2 3 4 5; do
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
  for p in $(sed -n "s/^$1 //p" $config); do
    echo $2 | grep -Eq "$p" 2>/dev/null && return 0 || :
  done
  return 1
}
