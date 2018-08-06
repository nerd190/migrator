#!/system/bin/sh
# App Data Keeper (adk) Core
# (c) 2018, VR25 @ xda-developers
# License: GPL v3+


modID=adk
modData=/data/media/$modID
config=$modData/config.txt
appData=$modData/.appData
apksBkp=$modData/apksBkp


# read installed apks (in post fs data mode)
# treat updated system apps as user apps
# check white (system) and black (user) lists (include/exclude)
# blacklisting rules also apply to system apps treated as user apps
main() {
  grep 'package name' /data/system/packages.xml | \
  awk '{print $2,$3}' | sed 's:"::g; s:name=::; s:codePath=::' | \
  while read line; do
    if echo "$line" | grep -q '/system/' && ! \
    [[ -f /data/app/$(pkg_name)\-1/base.apk || \
    -f /data/app/$(pkg_name)\-2/base.apk ]]; then
      if grep -v '^#' $config 2>/dev/null | grep -q "$(pkg_name)"; then
        lsck system
      else
        restore_excluded
      fi
    else
      if ! grep -v '^#' $config 2>/dev/null | grep -q "$(pkg_name)"; then
        lsck user
      else
        restore_excluded
      fi
    fi
  done
}


# bind-mount or move & bind-mount
# $1=user or system
lsck() {
  if [ -n "$(ls "$appData/$(pkg_name)" 2>/dev/null)" ]; then
    bindf $line $1
  else
    movef $line
    bindf $line $1
  fi
}


pkg_name() { echo $line | awk '{print $1}'; }


restore_excluded() {
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
      rm -rf "/data/data/$line" 2>/dev/null
      mv "$appData/$line" /data/data/
    done
  else
    # move app data to $appData
    rm -rf $appData/$1 2>/dev/null
    mkdir -p $appData/${1}_tmp
    mv /data/data/$1/* $appData/${1}_tmp
    $modPath/bin/rsync -a /data/data/$1 $appData/
    mv $appData/${1}_tmp/* $appData/$1
    rmdir $appData/${1}_tmp
  fi
}


# $1=pkgName, $3=user or system
bindf() {
  if [ "$3" = "user" ]; then
    if [[ -f /data/app/${1}\-1/base.apk || -f /data/app/${1}\-2/base.apk ]]; then
      rm -rf /data/data/$1/* 2>/dev/null # cleanup obsolete data
      mount -o bind $appData/$1 /data/data/$1
    fi
  else
    mount -o bind $appData/$1 /data/data/$1
  fi
}


# wait 90 seconds for external storage
wait4sd() {
  if [ "$1" != "nowait" ]; then
    count=0
    until [ "$count" -ge 360 ]; do
      ((count++))
      grep -q '/mnt/media_rw' /proc/mounts && break || sleep 4
    done
  fi
  grep -q '/mnt/media_rw' /proc/mounts \
    && apksBkp="$(ls -1d /mnt/media_rw/* | head -n1)/$modID/apksBkp"
  mkdir -p $apksBkp 2>/dev/null
}


# backup all apks in /data/app (in late start service mode)
# defaultStorage=external
# fallBackStorage=internal
bkp_apks() {
  wait4sd
  find /data/app -type f -name base.apk | \
    while read line; do
       $modPath/bin/rsync -c --partial $line "$apksBkp/$(dirname $line | sed 's:/data/app/::; s:-[1-2]::').apk"
    done
}


# batch restore apks from terminal
res_apks() {
  echo
  wait4sd nowait
  cd $apksBkp
  ls -1
  echo -e "\nInput matching pattern (or nothing to cancel)..."
  read pattern
  echo
  ls -1 | grep -E "$pattern" 2>/dev/null | \
    while read line; do
      [ -n "$line" ] && { echo -n "Installing $line..."; echo " $(pm install -r $line)"; }
    done
  echo
}


# rollback all app data from recovery
resdata () {
  echo -e "\nMove all app data back to /data/data (y/N) and uninstall adk?"
  read ans
  if echo "$ans" | grep -iq y; then
    echo -e "\nPlease wait...\n"
    movef restore
    [ "$?" -eq "0" ] && rm -rf $mountPoint/adk $modData
  fi
}
