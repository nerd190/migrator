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
  if grep -q '^[a-z]' $config 2>dev/null || [ -n "$(ls "$appData" 2>/dev/null)" ]; then
    grep 'package name' /data/system/packages.xml | \
    awk '{print $2,$3}' | sed 's:"::g; s:name=::; s:codePath=::' | \
    while read line; do
      if echo "$line" | grep -q '/system/' \
        && ! [ -d "/data/app/$(pkg_name)-1" -o -d "/data/app/$(pkg_name)-2" ]
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

app_name() { echo $APK | sed 's/\.apk//'; }


restore_exc() {
  if [ -n "$(ls "$appData/$(pkg_name)" 2>/dev/null)" ]; then
    rm -rf "/data/data/$(pkg_name)"
    mv "$appData/$(pkg_name)" /data/data/
  fi
}


# move app data to $appData
# $1=pkgName or "restore"
movef() {
  { mkdir -p $appData
  rm -rf $appData/$1; } 2>/dev/null
  mv /data/data/$1 $appData/
}


# bind-mount app data
# $1=pkgName, $3=user or system
bindm() {
  rm -rf /data/data/$1 2>/dev/null # remove obsolete data
  mkdir /data/data/$1
  mount -o bind $appData/$1 /data/data/$1
}


# wait 90 seconds for external storage
find_sdcard() {
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


# backup all APK's in /data/app (in late start service mode)
# defaultStorage=external
# fallBackStorage=internal
bkp_apps() {
  find_sdcard
  for APK in $(find /data/app -type f -name base.apk); do
     $modPath/bin/rsync -u --inplace $APK "$apksBkp/$(dirname $APK | sed 's:/data/app/::; s:-[1-2]::').apk"
  done
}


# batch restore APK's from terminal
restore_apps() {
  echo
  find_sdcard nowait
  if [ -n "$(ls $apksBkp 2>/dev/null)" ]; then
    cd /data/app
    ls $apksBkp
    echo
    echo -n "\n(i) Input matching pattern(s) (i.e., single: sp.*fy (spotify), multiple: duk|whats|faceb, or . (a dot) for all)... "
    read PATTERN
    echo
    set +u
    [ -n "$PATTERN" ] && echo || { echo -e "(!) Operation aborted -- null input\n"; exit 0; }
    ls "$apksBkp" | grep -Eq "$PATTERN" || { echo -e "(!) \"$PATTERN\" doesn't match any APK(s) in $apksBkp\n"; exit 0; }
    set -u
    replaceAll=false
    skipAll=false
    echo "Working..."
    for APK in $(ls "$apksBkp" | grep -E "$PATTERN"); do
      replace=false
      if [ -d "$(app_name)-1" -o -d "$(app_name)-2" ]; then
        if ! $replaceAll && ! $skipAll; then
          replace_apk
        fi
        if $replace || $replaceAll; then
          install_apk
        fi
      else
        install_apk
      fi
    done
    if $replace || $replaceAll; then
      echo -e "\n(i) Done. Reboot to apply changes.\n"
    else
      echo -e "(i) No app(s) restored\n"
    fi
  else
    echo -e "(!) Backup directory empty or not found\n"
  fi
}


install_apk() {
  if $replace || $replaceAll; then
    rm -rf "$(app_name)-1" "$(app_name)-2" 2>/dev/null
  fi
  echo "  - $APK"
  mkdir "$(app_name)-1"
  cp "$apksBkp/$APK" "$(app_name)-1/base.apk"
  chmod 755 "$(app_name)-1"
  chmod 644 "$(app_name)-1/base.apk"
  chown -R '1000:1000' "$(app_name)-1"
  chcon -R 'u:object_r:apk_data_file:s0' "$(app_name)-1"
}


replace_apk() {
  echo -e "\n  $APK is already installed. Replace?"
  cat <<OPTS
    y) Yes
    n) No
    a) Yes, all
    s) Skip all
OPTS
  echo -n "    ... "
  read ANS
  echo
  set +u
  case $ANS in
      y) replace=true;;
      n) replace=false;;
      a) replaceAll=true;;
      s) skipAll=true;;
      *) replace_apk;;
  esac
  set -u
}


# Remove uninstalled APK's from backup folder
rm_uninstalled() {
  echo
  cd /data/app
  removed=false
  find_sdcard nowait
  for APK in $(ls $apksBkp 2>/dev/null); do
    if [ -n "$APK" ]; then
      if ! [ -d "$(app_name)-1" -o -d "$(app_name)-2" ]; then
        echo "rm $APK"
        rm "$apksBkp/$APK"
        removed=true
      fi
    fi
  done
  $removed && echo || echo -e "(i) Nothing to remove\n"
}
