#!/system/bin/sh
# App Data Keeper (adk) Core
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


modID=adk
modData=/data/media/$modID
config=$modData/config.txt
appData=$modData/.appData
apksBkp=$modData/apksBkp
pkgList=/data/system/packages.list


# read installed APKs (in early post-fs-data mode)
# treat updated system apps as user apps
main() {
  if grep -q '^[a-z]' $config 2>dev/null || [ -n "$(ls "$appData" 2>/dev/null)" ]; then
    awk '{print $1,$2}' $pkgList | \
      while read line; do
        (LINE=$line
        if ! [ -d "/data/app/$(pkg_name_)-1" -o -d "/data/app/$(pkg_name_)-2" ]; then
          # system app
          if grep -q "^inc $(pkg_name_)" $config 2>/dev/null; then
            mv_bindm
          else
            restore_exc $LINE
          fi
        else
          # treat as user app
          if grep -Eq "^inc $(pkg_name_)|^inc$" $config 2>/dev/null \
            && ! grep -q "^exc $(pkg_name_)" $config 2>/dev/null
          then
            mv_bindm
          else
            restore_exc $LINE
          fi
        fi) &
      done
    # prepare list of non-compiled apps
    : >$modData/.pending
    for d in /data/app/*-1; do
      ls -d "$d"/* | grep -q '[a-z]' || echo "$d" | sed 's/-[0-9]//' >>$modData/.pending
    done
    wait # for background jobs to finish
  fi
}


pending_apps() {
  if [ -f "$modData/.pending" ]; then
    for line in $(cat $modData/.pending); do
      (LINE_=$line
      until grep -q "$LINE_" $pkgList; do sleep 1; done
      LINE="$(grep "$LINE_" $pkgList | awk '{print $1,$2}')"
      if grep -Eq "^inc $(pkg_name_)|^inc$" $config 2>/dev/null \
          && ! grep -q "^exc $(pkg_name_)" $config 2>/dev/null
      then
        mv_bindm
      else
        restore_exc $LINE
      fi) &
    done
  fi
}


pkg_name_() { echo $LINE | awk '{print $1}'; }
pkg_name() { echo $APK | sed 's/\.apk//'; }


# bind-mount or move & bind-mount
# $1=user or system
mv_bindm() {
  if [ -n "$(ls "$appData/$(pkg_name_)" 2>/dev/null)" ]; then
    bindm $LINE
  else
    movef $LINE
    bindm $LINE
  fi
}


# restore excluded data
restore_exc() {
  if [ -n "$(ls "$appData/$1")" ] \
    && grep -q "$1" $pkgList # if pkg is installed
  then
    rm -rf "/data/data/$1"
    mv "$appData/$1" /data/data/
    chown -R "${2}:$2" /data/data/$1
  fi 2>/dev/null
}


# move app data to $appData
# $1=pkg_name_
movef() {
  mkdir -p $appData
  rm -rf $appData/$1 # remove obsolete data
  mv /data/data/$1 $appData/
} 2>/dev/null


# bind-mount app data
# $1=pkg_name_, $2=owner
bindm() {
  rm -rf /data/data/$1 2>/dev/null # remove obsolete data
  mkdir /data/data/$1
  chown -R "${2}:$2" /data/data/$1 $appData/$1 2>/dev/null
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


# batch restore APK's
restore_apps() {
  echo
  find_sdcard nowait # do not wait for external storage
  if [ -n "$(ls $apksBkp 2>/dev/null)" ]; then
    cd /data/app
    ls $apksBkp
    echo
    echo -n "(i) Input matching pattern(s) (i.e., single: sp.*fy (spotify), multiple: duk|whats|faceb, or . (a dot) for all)... "
    read PATTERN
    echo
    set +u
    [ -n "$PATTERN" ] || { echo -e "(!) Operation aborted -- null input\n"; exit 0; }
    ls "$apksBkp" | grep -Eq "$PATTERN" || { echo -e "(!) \"$PATTERN\" doesn't match any APK(s) in $apksBkp\n"; exit 0; }
    set -u
    replaceAll=false
    skipAll=false
    echo "Working..."
    for APK in $(ls "$apksBkp" | grep -E "$PATTERN"); do
      replace=false
      if [ -d "$(pkg_name)-1" -o -d "$(pkg_name)-2" ]; then
        if ! $replaceAll && ! $skipAll; then
          replace_apk
        fi
        if $replace || $replaceAll; then
          install_apk
        fi
      else
        replace=true
        install_apk
      fi
    done
    if $replace || $replaceAll; then
      echo -e "\n(i) Done. Reboot to apply changes."
      echo -e "- Note: if a lot of apps were restored, the next boot might take a little while. Be patient.\n"
    else
      echo -e "(i) No app(s) restored\n"
    fi
  else
    echo -e "(!) Backup directory empty or not found\n"
  fi
}


install_apk() {
  if $replace || $replaceAll; then
    rm -rf "$(pkg_name)-1" "$(pkg_name)-2" 2>/dev/null
  fi
  echo "  - $APK"
  mkdir "$(pkg_name)-1"
  cp "$apksBkp/$APK" "$(pkg_name)-1/base.apk"
  { chown -R '1000:1000' "$(pkg_name)-1"
  chmod -R 755 "$(pkg_name)-1"
  chmod 644 "$(pkg_name)-1/base.apk"
  chcon -R 'u:object_r:apk_data_file:s0' "$(pkg_name)-1"; } 2>/dev/null
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
      if ! [ -d "$(pkg_name)-1" -o -d "$(pkg_name)-2" ]; then
        echo "rm $APK"
        rm "$apksBkp/$APK"
        removed=true
      fi
    fi
  done
  $removed && echo || echo -e "(i) Nothing to remove\n"
}
