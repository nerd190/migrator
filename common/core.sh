#!/system/bin/sh
# App Data Keeper (adk) Core
# Copyright (C) 2018, VR25 @ xda-developers
# License: GPL v3+


modId=adk
modData=/data/media/$modId
Config=$modData/config.txt
appData=$modData/appdata
appBkps=$modData/backups/apk
pkgList=/data/system/packages.list
appdataBkps=$modData/backups/appdata

# app data backup frequency (in hours)
bkpFreq="$(sed -n 's/^bkpFreq=//p' "$Config" 2>/dev/null)"
[ -z "$bkpFreq" ] && bkpFreq=8 # fallback


# parse /data/system/packages.list (in early post-fs-data mode)
# treat updated system apps as user apps
main() {
  if grep -q '^[a-z]' $Config 2>dev/null || [ -n "$(ls "$appData" 2>/dev/null)" ]; then
    awk '{print $1,$2}' $pkgList | \
      while read line; do
        (LINE=$line
        if ! [ -d "/data/app/$(pkg_name_)-1" -o -d "/data/app/$(pkg_name_)-2" ]; then
          # system app
          if grep -q "^inc $(pkg_name_)" $Config 2>/dev/null; then
            mv_bind_mount
          else
            restore_exc $LINE
          fi
        else
          # treat as user app
          if grep -Eq "^inc $(pkg_name_)|^inc$" $Config 2>/dev/null \
            && ! grep -q "^exc $(pkg_name_)" $Config 2>/dev/null
          then
            mv_bind_mount
          else
            restore_exc $LINE
          fi
        fi) &
      done
    wait # for background jobs to finish
  fi
}


pkg_name_() { echo "$LINE" | awk '{print $1}'; }
pkg_name() { echo $APK | sed 's/\.apk//'; }


# bind-mount or move & bind-mount
# $1=pkgName $2=dataOwner
mv_bind_mount() {
  if [ -n "$(ls "$appData/$(pkg_name_)" 2>/dev/null)" ]; then
    bind_mount $LINE
  else
    movef $LINE
    bind_mount $LINE
  fi
}


# restore excluded data
restore_exc() {
  if [ -n "$(ls "$appData/$1")" ]; then
    rm -rf "/data/data/$1"
    mv "$appData/$1" /data/data/
    chown -R "$2:$2" /data/data/$1
  fi 2>/dev/null
}


# move app data to $appData
# $1=pkg_name_
movef() {
  mkdir -p $appData
  rm -rf $appData/$1 # remove obsolete data
  mv /data/data/$1 $appData/
} 2>/dev/null


# bind-mount $ppData/pkgName to /data/data/pkgName
# $1=pkgName, $2=dataOwner
bind_mount() {
  rm -rf /data/data/$1 2>/dev/null # remove obsolete data
  mkdir /data/data/$1
  chown -R "$2:$2" /data/data/$1 $appData/$1 2>/dev/null
  mount -o bind $appData/$1 /data/data/$1
}


# wait 90 seconds for external storage
# If multiple partitions are found, use the largest for backups
find_sdcard() {
  set +u
  if [ "$1" != "nowait" ]; then
    set -u
    Count=0
    until [ "$Count" -ge "360" ]; do
      ((Count++))
      grep -q '/mnt/media_rw' /proc/mounts && break || sleep 4
    done
  fi
  set -u
  if grep -q '/mnt/media_rw' /proc/mounts; then
    # wait for additional partitions to be mounted
    set +u
    [ "$1" = "nowait" ] || sleep 4
    set -u
    Size=0
    for d in /mnt/media_rw/*; do
      newSize="$(df "$d" | tail -n1 | awk '{print $2}')"
      if [ "$newSize" -gt "$Size" ]; then
        Size=$newSize
        sdCard="$d"
        appBkps="$d/adk/backups/apk"
        appdataBkps="$d/adk/backups/appdata"
        i=/sdcard
        e="$sdCard"
      fi
    done
  fi
}


# backup APK's (begins in late start service mode)
# defaultStorage=external
# fallBackStorage=internal
bkp_apps() {
  mkdir -p "$appBkps" "$appdataBkps" 2>/dev/null
  for APK in $(find /data/app -type f -name base.apk); do
    pkgName="$(dirname $APK | sed 's:/data/app/::; s:-[0-9]::')"
    if grep -Eq "^inc $pkgName|^inc$" $Config 2>/dev/null \
        && ! grep -q "^exc $pkgName" $Config 2>/dev/null
    then
      $modPath/bin/rsync -tu --inplace $APK "$appBkps/${pkgName}.apk"
    fi
  done
}


# Remove all backups of uninstalled apps
rm_uninstalled() {
  removed=false
  for Pkg in $(ls $appdataBkps 2>/dev/null | grep -v 'lost+found'); do
    if ! grep -q "$Pkg" "$pkgList"; then
      echo "- $Pkg"
      [ -f "$appBkps/$Pkg" ] && rm "$appBkps/$Pkg"
      [ -d "$appdataBkps/$Pkg" ] && rm -rf "$appdataBkps/$Pkg" 2>/dev/null
      removed=true
    fi
  done
  $removed && echo || echo -e "(i) Nothing to remove\n"
  exit_or_not
}


# incremental backup
rsync_util() {
  echo "(i) Use \$i for internal storage and \$e for external media (largest partition), instead of writing full paths. Example: rsync -hrtuv --inplace --progress --stats --del \$i/ \$e/full_internal_bkp".
  echo -n "\nrsync -hrtuv --inplace --progress --stats "
  read p
  echo
  while :; do
    echo "$modPath/bin/rsync -hrtuv --inplace --progress --stats $p" >$modData/.rsync_util_tmp
    . $modData/.rsync_util_tmp
    rm $modData/.rsync_util_tmp
    echo
    echo "(i) Next incremental backup in $bkpFreq hours"
    echo "- Press CTRL+C (Vol. Down + C) to cancel the schedule and exit."
    echo -n "- You may minimize this window."
    sleep $((bkpFreq * 3600))
    echo
    echo
  done
}


# incremental app data backup
bkp_appdata() {
  set +x
  while :; do
    for d in $(ls /data/data/); do
      if grep -q "$d" "$pkgList"; then
        if ! [ -d "/data/app/${d}-1" -o -d "/data/app/${d}-2" ]; then
          if grep -q "^inc $d" $Config 2>/dev/null; then
            set -x 2>>$newLog
            $modPath/bin/rsync -Drtu --del \
              --exclude=cache --exclude=code_cache --exclude=app_webview/GPUCache --exclude=symlinks.list \
              --inplace /data/data/$d "$appdataBkps"
            set +x
            bkp_symlinks
          fi
        else
          if grep -Eq "^inc $d|^inc$" $Config 2>/dev/null \
            && ! grep -q "^exc $d" $Config 2>/dev/null
          then
            set -x 2>>$newLog
            $modPath/bin/rsync -Drtu --del \
            --exclude=cache --exclude=code_cache --exclude=app_webview/GPUCacher --exclude=symlinks.list \
            --inplace /data/data/$d "$appdataBkps"
            set +x
            bkp_symlinks
          fi
        fi
      fi
    done
    set -x 2>>$newLog
    sleep $((bkpFreq * 3600))
    set +x
  done
}


restore_apps() {
  if ls "$appBkps" 2>/dev/null | grep -q '[a-z]'; then
    RestoreList=""
    for App in $(ls "$appBkps"); do
      echo "- $App"
      [ -z "$RestoreList" ] && RestoreList="$App" \
        || RestoreList="$RestoreList\n$App"
    done
    restore_prompt
    if grep -q '[a-z]' $modData/.restore_tmp; then
      echo -e "\n[Re]installing..."
      for Pkg in $(cat $modData/.restore_tmp); do
        echo -n "- $Pkg"
        grep -q "$(echo "$Pkg" | sed 's/\.apk//')" "$pkgList" \
          && { pm install -r "$appBkps/$Pkg" 1>/dev/null || :; } \
          || pm install "$appBkps/$Pkg" 1>/dev/null
        echo
      done
      post_restore apps apps
    else
      no_matches
    fi
  else
    missing_bkp
  fi
}


restore_data() {
  if ls "$appdataBkps" 2>/dev/null | grep -v 'lost+found' | grep -q '[a-z]'; then
    mk_restore_list installed
    restore_prompt
    if grep -q '[a-z]' $modData/.restore_tmp; then
      restore data data
    else
      no_matches
    fi
  else
    missing_bkp
  fi
}


restore_apps_and_data() {
  if ls "$appdataBkps" 2>/dev/null | grep -v 'lost+found' | grep -q '[a-z]'; then
    mk_restore_list not_installed
    if [ -z "$RestoreList" ]; then
      echo -e "(i) Nothing left to restore\n"
      select a in Exit "Main Menu" \
        "Restore apps (replace)" \
        "Restore apps' data (overwrite)"
      do
        case $a in
          Exit) echo; exit 0;;
          "Main Menu") wizard; break;;
          "Restore apps (replace)") reset; echo; restore_apps; break;;
          "Restore apps' data (overwrite)") reset; echo; restore_data; break;;
        esac
      done
    fi
    restore_prompt
    if grep -q '[a-z]' $modData/.restore_tmp; then
      restore apps+data apps_and_data
    else
      no_matches
    fi
  else
    missing_bkp
  fi
}


wizard() {
  find_sdcard nowait
  reset
  cat <<ACTIONS

App Data Keeper (adk) Wizard

Restore
  1) Apps (replace)
  2) Data (overwrite)
  3) Apps+data
Utilities
  4) Debugging info
  5) rsync -hrtuv --inplace --progress --stats \$@
  6) Remove all backups of uninstalled apps
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
    4) reset; echo; debug_info;;
    5) reset; echo; rsync_util;;
    6) reset; echo; rm_uninstalled;;
    *) echo; echo -n "  (!) Invalid choice"; sleep 2; wizard;;
  esac
}


backups() {
  # remove empty folders
  for d in $appData/*; do
    rmdir "$d" 2>/dev/null
  done
  find_sdcard
  bkp_apps
  (bkp_appdata) &
  if grep -q '^bkp ' $Config 2>/dev/null; then
    set +x
    while :; do
      sed -n "s:^bkp:$modPath/bin/rsync -rtu --inplace:p" \
        $Config 2>/dev/null >$modData/.backups_tmp
      set -x 2>>$newLog
      . $modData/.backups_tmp
      set +x
      rm $modData/.backups_tmp
      set -x 2>>$newLog
      sleep $((bkpFreq * 3600 + 3600)) # the extra hour prevents conflicts with bkp_appdata()
      set +x
    done
  fi
}


debug_info() {
  set
  echo
  exit_or_not
}


no_matches() {
  echo -e "\n(!) No match(es)\n"
  select a in Exit Retry "Main Menu"; do
    case $a in
      Exit) echo; exit 0;;
      Retry) reset; restore_apps_and_data; break;;
      "Main Menu") wizard; break;;
     esac
  done
}


missing_bkp() {
    echo -n "(!) Backup folder not found or empty"
    sleep 2
    wizard
}


post_restore() {
  rm $modData/.restore_tmp
  echo
  oPS3="$PS3"
  PS3="- Done. Now what? "
  select a in Exit "Main Menu" "Restore more $1"; do
    case $a in
      Exit) PS3="$oPS3"; echo; exit 0;;
      "Main Menu") PS3="$oPS3"; wizard; break;;
      "Restore more $1") PS3="$oPS3"; reset; restore_$2; break;;
    esac
  done
}


restore_prompt() {
  echo
  echo -n "(i) Input pattern(s) to match (i.e., sp.*fy or duk|faceb|whats. A dot matches all)... "
  read i
  : >$modData/.restore_tmp
  [ -n "$i" ] && echo -e "$RestoreList" | grep -E "$i" >$modData/.restore_tmp
}


mk_restore_list() {
  RestoreList=""
  for App in $(ls "$appdataBkps" | grep -v 'lost+found'); do
    [ "$1" = not_installed ] && { grep -q "$App" "$pkgList" && Test=false || Test=true; } \
      || { grep -q "$App" "$pkgList" && Test=true || Test=false; }
    if $Test; then
      echo "- $App"
      [ -z "$RestoreList" ] && RestoreList="$App" \
        || RestoreList="$RestoreList\n$App"
    fi
  done
}


restore() {
  echo -e "\nRestoring $1..."
  for Pkg in $(cat $modData/.restore_tmp); do
    echo -n "- $Pkg"
    [ "$1" = "apps+data" ] && pm install "$appBkps/${Pkg}.apk" 1>/dev/null
    [ "$1" = "apps+data" ] || pm disable "$Pkg" 1>/dev/null
    $modPath/bin/rsync -Drt --del --exclude=symlinks.list "$appdataBkps/$Pkg/" "/data/data/$Pkg"
    restore_symlinks
    [ "$1" = "apps+data" ] || pm enable "$Pkg" 1>/dev/null
    o="$(grep "$Pkg" "$pkgList" | awk '{print $2}')"
    chown -R "$o:$o" "/data/data/$Pkg"
    chmod -R 771 "/data/data/$Pkg"
    echo
  done
  post_restore $1 $2
}


exit_or_not() {
  select a in Exit "Main Menu"; do
    case $a in
      Exit) echo; exit 0;;
      "Main Menu") wizard; break;;
     esac
  done
}


bkp_symlinks() {
  : >"$appdataBkps/$d/symlinks.list"
  for l in $(find /data/data/$d -type l); do
    echo "`readlink -f $l` $l" >>"$appdataBkps/$d/symlinks.list" 2>/dev/null
  done
}


restore_symlinks() {
  cat "$appdataBkps/$Pkg/symlinks.list" | \
    while read line; do
      ln -s $line 2>/dev/null
    done
}
