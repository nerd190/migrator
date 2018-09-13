#!/system/bin/sh
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
bkpFreq="$(sed -n 's/^bkpFreq=//p' "$Config" 2>/dev/null || true)"
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
      newSize=$(df "$e" | tail -n1 | awk '{print $2}')
      if [ "$newSize" -gt "$Size" ]; then
        Size=$newSize
        apkBkps="$e/adk/backups/apk"
        appDataBkps="$e/adk/backups/appdata"
      fi
    done
  fi
}


# backup APK's
# defaultStorage=external ($e)
# fallBackStorage=internal ($i)
bkp_apps() {
  local Pkg pkgName
  mkdir -p "$apkBkps" "$appDataBkps"
  for Pkg in $(find /data/app -type f -name base.apk); do
    pkgName=$(dirname $Pkg | sed 's:/data/app/::; s:-[0-9]::')
    if { grep -q '^inc$' $Config || match_test inc $pkgName; } \
      && ! match_test exc $pkgName
    then
      $rsync -tu --inplace $Pkg "$apkBkps/$pkgName.apk"
    fi
  done
}


# Remove all backups of uninstalled apps
rm_uninstalled() {
  local Pkg
  bkps_path
  if ls -p $appDataBkps 2>/dev/null | grep -q /; then
    mk_list not_installed
    if grep -q '[a-z]' $tmpDir/pkg_list0; then
      regex_prompt
      if grep -q '[a-z]' $tmpDir/pkg_list; then
        echo -e "\n(i) Removing..."
        for Pkg in $(cat $tmpDir/pkg_list); do
          echo "- $Pkg"
          [ -f "$apkBkps/$Pkg" ] && rm "$apkBkps/$Pkg"
          [ -d "$appDataBkps/$Pkg" ] && rm -rf "$appDataBkps/$Pkg"
        done
        echo
      else
        no_matches rm_uninstalled
      fi
    else
      echo -e "(i) Nothing to remove\n"
    fi
    exit_or_not
  else
    missing_bkp
  fi
}


# generic incremental backup utility
rsync_util() {
  local i
  echo "(i) Use \$i for internal storage and \$e for external media (largest partition), instead of writing full paths. Example: rsync -hrtuv --inplace --progress --stats --del \$i/ \$e/full_internal_bkp".
  echo -n "\nrsync -hrtuv --inplace --progress --stats "
  read i
  echo
  while :; do
    eval $rsync -hrtuv --inplace --progress --stats $i
    echo
    echo "(i) Next incremental backup in $bkpFreq hours"
    echo "- Press CTRL+C (Vol. Down + C) to cancel the schedule and exit."
    echo -n "- You may minimize this window."
    sleep $((bkpFreq * 3600))
    echo
    echo
  done
}


# incremental apps data backup
bkp_appdata() {
  local Pkg
  while true; do
    for Pkg in $(awk '{print $1}' $pkgList); do
      if ! ls -p /data/app/$Pkg* 2>/dev/null | grep -q /; then
        if match_test inc $Pkg; then
          $rsync -Drtu --del \
            --exclude=cache --exclude=code_cache \
            --exclude=app_webview/GPUCache --exclude=symlinks.list \
            --inplace /data/data/$Pkg "$appDataBkps" >/dev/null 2>&1 || true
          bkp_symlinks
        fi
      else
        if { grep -q '^inc$' $Config || match_test inc $Pkg; } \
          && ! match_test exc $Pkg
        then
          $rsync -Drtu --del \
            --exclude=cache --exclude=code_cache \
            --exclude=app_webview/GPUCache --exclude=symlinks.list \
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


restore_apps() {
  local Pkg
  bkps_path
  if ls $apkBkps 2>/dev/null | grep -q .apk; then
    : >$tmpDir/pkg_list0
    for Pkg in $(ls -1 $apkBkps); do
      echo "- $Pkg"
      echo $Pkg >>$tmpDir/pkg_list0
    done
    regex_prompt
    if grep -q '[a-z]' $tmpDir/pkg_list; then
      echo -e "\n[Re]installing..."
      Pkg=""
      for Pkg in $(cat $tmpDir/pkg_list); do
        echo -n "- $Pkg"
        if grep -q "${Pkg%.apk}" "$pkgList"; then
          pm install -r "$apkBkps/$Pkg" 1>/dev/null || true
        else
          pm install "$apkBkps/$Pkg" 1>/dev/null || true
        fi
        echo
      done
      post_restore apps apps
    else
      no_matches restore_apps
    fi
  else
    missing_bkp
  fi
}


restore_data() {
  bkps_path
  if ls -p $appDataBkps 2>/dev/null | grep -q /; then
    mk_list installed
    regex_prompt
    if grep -q '[a-z]' $tmpDir/pkg_list; then
      restore data data
    else
      no_matches restore_data
    fi
  else
    missing_bkp
  fi
}


restore_apps_and_data() {
  local o
  bkps_path
  if ls $appDataBkps 2>/dev/null | grep -q .; then
    mk_list not_installed
    if ! grep -q '[a-z]' $tmpDir/pkg_list0; then
      echo -e "(i) Nothing left to restore\n"
      select o in Exit "Main menu" \
        "Restore apps (replace)" \
        "Restore apps data (overwrite)"
      do
        case $o in
          Exit) echo; exit 0;;
          "Main menu") wizard; break;;
          "Restore apps (replace)") reset; echo; restore_apps; break;;
          "Restore apps data (overwrite)") reset; echo; restore_data; break;;
        esac
      done
    fi
    set -u
    regex_prompt
    if grep -q '[a-z]' $tmpDir/pkg_list; then
      restore apps+data apps_and_data
    else
      no_matches restore_apps_and_data
    fi
  else
    missing_bkp
  fi
}


wizard() {
  local o
  find_sdcard nowait
  reset
  cat <<ACTIONS

App Data Keeper (adk) Wizard

Restore
  1) Apps (replace)
  2) Data (overwrite)
  3) Apps+data
Utilities
  4) Test backupd()
  5) Debugging info
  6) rsync -hrtuv --inplace --progress --stats \$@
  7) Remove select backups of uninstalled apps
---
  0) Exit

ACTIONS

  echo -n "(i) Choose an option... "
  read o

  case $o in
    0) echo -e "\n  Goodbye.\n"; exit 0;;
    1) reset; echo; restore_apps;;
    2) reset; echo; restore_data;;
    3) reset; echo; restore_apps_and_data;;
    4) reset; echo; backupd ondemand;;
    5) reset; echo; debug_info;;
    6) reset; echo; rsync_util;;
    7) reset; echo; rm_uninstalled;;
    *) echo; echo -n "  (!) Invalid choice!"; sleep 2; wizard;;
  esac
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
    # does unsetting functions and variables really save memory?
    #unset apkBkps failedRes migratedData modId modData defaultConfig
    #for f in find_sdcard bkp_apps rm_uninstalled retry_failed_restores \
     # rsync_util bkp_apps bkp_appdata restore_apps_and_data restore_apps \
      #restore_data wizard debug_info no_matches missing_bkp post_restore \
      #regex_prompt mk_list restore exit_or_not restore_symlinks bkps_path \
      #restore_on_boot wait_booted
    #do
      #unset -f $f
    #done
    (bkp_appdata) &
  else
    set -u
    find_sdcard nowait
    echo -n "(i) Backing up APK's..."
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


debug_info() {
  getprop | grep -Ei 'product|version'
  echo
  set
  echo
  echo "SELinux status: $(getenforce 2>/dev/null || sestatus 2>/dev/null)" \
    | sed 's/En/en/;s/Pe/pe/'
  echo
  exit_or_not
}


no_matches() {
  local o
  echo -e "\n(!) No match(es)!\n"
  select o in Exit Retry "Main menu"; do
    case $o in
      Exit) echo; exit 0;;
      Retry) reset; $1; break;;
      "Main menu") wizard; break;;
    esac
  done
}


missing_bkp() {
    echo -e "\n(!) Backup folder not found or empty!\n"
    exit_or_not
}


post_restore() {
  local o
  echo
  echo "Done. Now what?"
  select o in Exit "Main menu" "Restore more $1"; do
    case $o in
      Exit) echo; exit 0;;
      "Main menu") wizard; break;;
      "Restore more $1") reset; restore_$2; break;;
    esac
  done
}


regex_prompt() {
  local i
  echo
  echo -n "(i) Input pattern(s) to match (i.e., sp.*fy or duk|faceb|whats. A dot matches all)... "
  read i
  [ -n "$i" ] && cat $tmpDir/pkg_list0 | grep -E "$i" 2>/dev/null >$tmpDir/pkg_list || true
}


mk_list() {
  local Pkg Test
  : >$tmpDir/pkg_list0
  for Pkg in $(ls -1 $appDataBkps); do
    [ "$1" = not_installed ] && { grep -q "$Pkg" "$pkgList" && Test=false || Test=true; } \
      || { grep -q "$Pkg" "$pkgList" && Test=true || Test=false; }
    if $Test; then
      echo "- $Pkg"
      echo $Pkg >>$tmpDir/pkg_list0
    fi
  done
}


restore() {
  local Pkg o
  echo -e "\nRestoring $1..."
  for Pkg in $(cat $tmpDir/pkg_list); do
    echo -n "- $Pkg"
    [ "$1" = "apps+data" ] && { pm install "$apkBkps/$Pkg.apk" 1>/dev/null || true; }
    pm disable "$Pkg" 1>/dev/null || true
    $rsync -Drt --del --exclude=symlinks.list "$appDataBkps/$Pkg/" /data/data/$Pkg
    echo
    restore_symlinks
    o=$(grep "$Pkg" "$pkgList" | awk '{print $2}')
    chown -R $o:$o /data/data/$Pkg
    chmod -R 771 /data/data/$Pkg
    pm enable "$Pkg" 1>/dev/null
  done
  post_restore $1 $2
}


exit_or_not() {
  local o
  select o in Exit "Main menu"; do
    case $o in
      Exit) echo; exit 0;;
      "Main menu") wizard; break;;
     esac
  done
}


bkp_symlinks() {
  local l
  : >"$appDataBkps/$Pkg/symlinks.list"
  for l in $(find /data/data/$Pkg -type l); do
    echo "$(readlink -f $l) $l" >>"$appDataBkps/$Pkg/symlinks.list" 2>/dev/null
  done
}


restore_symlinks() {
  local l
  cat "$appDataBkps/$Pkg/symlinks.list" | \
    while read l; do
      ln -s $l 2>/dev/null
    done
}


restore_on_boot() {
  local Pkg o
  if ls -p $migratedData 2>/dev/null | grep -q / \
    && ! grep -q noauto $Config
  then
    set +e
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
    set -e
  fi
}


# wait until system has fully booted
wait_booted() {
  until [ "$(getprop init.svc.bootanim)" = stopped ] \
    && grep -q /storage/emulated /proc/mounts; do sleep 5; done
}


bkps_path() {
  local o bkpsDir=${apkBkps%/*}
  echo -e "Backups location...\n"
  select o in "$bkpsDir/ (default)" "$bkpsDir.old/" "<custom>" \
    "Return to main menu" Exit
  do
    case $o in
      "$bkpsDir.old/") bkpsDir=$bkpsDir.old;;
      "<custom>") echo -n "Custom path: "; read bkpsDir;;
      "Return to main menu") wizard;;
      Exit) echo; exit 0;;
    esac
    if [ -d $bkpsDir/apk -a -d $bkpsDir/appdata ]; then
      apkBkps=$bkpsDir/apk
      appDataBkps=$bkpsDir/appdata
    else
      echo -e "\n(!) Empty/invalid location! \n"
      bkps_path # recurse
    fi
    break
  done
  reset
  echo
}


retry_failed_restores() {
  local c
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
  local p
  for p in $(sed -n "s/^$1 //p" $Config); do
    echo $2 | grep -Eq "$p" 2>/dev/null && return 0 || true
  done
  return 1
}
