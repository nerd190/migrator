#!/system/bin/sh
# App Data Keeper (adk) Core
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


modID=adk
modData=/data/media/$modID
config=$modData/config.txt
appData=$modData/.appData
apksBkp=$modData/apksBkp


# read installed apks (in post-fs-data mode)
# treat updated system apps as user apps
main() {
  if grep -v '^#' $config 2>dev/null | grep -q '[a-z]' || [ -n "$(ls "$appData" 2>/dev/null)" ]; then
    grep 'package name' /data/system/packages.xml | \
    awk '{print $2,$3}' | sed 's:"::g; s:name=::; s:codePath=::' | \
    while read line; do
      if echo "$line" | grep -q '/system/' \
        && ! [ -f /data/app/$(pkg_name)\-1/base.apk -o -f /data/app/$(pkg_name)\-2/base.apk ]
      then
        if grep -q "^inc $(pkg_name)" $config 2>/dev/null; then
          (mv_bindm) &
        else
          (restore_exc) &
        fi
      else
        if grep -Eq "^inc $(pkg_name)|^inc$" $config 2>/dev/null \
          && ! grep -q "^exc $(pkg_name)" $config 2>/dev/null
        then
          (mv_bindm) &
        else
          (restore_exc) &
        fi
      fi
    done
  fi
}


# bind-mount or move & bind-mount
# $1=user or system
mv_bindm() {
  if [ -n "$(ls "$appData/$(pkg_name)" 2>/dev/null)" ]; then
    bindm $line
  else
    movef $line
    bindm $line
  fi
}


pkg_name() { echo $line | awk '{print $1}'; }


restore_exc() {
  if [ -n "$(ls "$appData/$(pkg_name)" 2>/dev/null)" ]; then
    rm -rf "/data/data/$(pkg_name)"
    mv "$appData/$(pkg_name)" /data/data/
  fi
}


# $1=pkgName or "restore"
movef() {
  if [ "$1" = "restore" ]; then
    # restore all app data in $appData to /data/data
    for line in $(ls $appData); do
      (rm -rf "/data/data/$line" 2>/dev/null
      mv "$appData/$line" /data/data/) &
    done
    wait
  else
    # move app data to $appData
    { mkdir -p $appData
    rm -rf $appData/$1; } 2>/dev/null
    mv /data/data/$1 $appData/
  fi
}


# bind-mount app data
# $1=pkgName, $3=user or system
bindm() {
  rm -rf /data/data/$1 2>/dev/null # remove obsolete data
  mkdir /data/data/$1
  mount -o bind $appData/$1 /data/data/$1
}


# wait 90 seconds for external storage
wait4sd() {
  set +u
  if [ "$1" != "nowait" ]; then
    set -u
    count=0
    until [ "$count" -ge 360 ]; do
      ((count++))
      grep -q '/mnt/media_rw' /proc/mounts && break || sleep 4
    done
  fi
  set -u
  grep -q '/mnt/media_rw' /proc/mounts \
    && apksBkp="$(ls -1d /mnt/media_rw/* | head -n1)/$modID/apksBkp"
  [ -d "$apksBkp" ] || mkdir -p $apksBkp
}


# backup all apks in /data/app (in late start service mode)
# defaultStorage=external
# fallBackStorage=internal
bkp_apps() {
  wait4sd
  find /data/app -type f -name base.apk | \
    while read line; do
       $modPath/bin/rsync -u --inplace --partial $line "$apksBkp/$(dirname $line | sed 's:/data/app/::; s:-[1-2]::').apk"
    done
}


# batch restore apks from terminal
restore_apps() {
  echo
  wait4sd nowait
  cd $apksBkp
  ls -1
  echo -e "\nInput matching pattern (or nothing to cancel)..."
  read pattern
  echo
  set +u
  ls -1 | grep -E "$pattern" 2>/dev/null | \
    while read line; do
      [ -n "$line" ] && { echo -n "Installing $line..."; echo " $(pm install -r $line)"; }
    done
  echo
  set -u
}


# rollback all app data from recovery
restore_data () {
  echo -e "\nMove all app data back to /data/data (y/N) and uninstall adk?"
  read ans
  if echo "$ans" | grep -iq y; then
    echo -e "\nPlease wait...\n"
    movef restore
    [ "$?" -eq "0" ] && rm -rf $mountPoint/adk $modData
  fi
}
