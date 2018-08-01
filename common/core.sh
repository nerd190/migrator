#!/system/bin/sh
# App Data Keeper (adk) Core
# (c) 2018, VR25 @ xda-developers
# License: GPL v3+


# environment

modID=adk
modData=/data/media/$modID
config=$modData/config.txt
appData=$modData/.appData
apksBkp=$modData/apksBkp
[ -z "$resdata" ] && PATH=/sbin/.core/busybox:/dev/magisk/bin


# read installed apks (in post fs data mode)
# treat updated system apps as user apps
# check white (system) and black (user) lists (include/exclude)
# blacklisting rules also apply to system apps treated as user apps
main() {
  grep 'package name' /data/system/packages.xml | \
  awk '{print $2,$3}' | sed 's:"::g; s:name=::; s:codePath=::' | \
  while read line; do
    if echo "$line" | grep -q '/system/' && ! \
    [[ -f /data/app/$(echo $line | awk '{print $1}')\-1/base.apk || \
    -f /data/app/$(echo $line | awk '{print $1}')\-2/base.apk ]]
    then
      if grep -q "$(echo $line | awk '{print $1}')" $config 2>/dev/null; then
        if [ -n "$(ls "$appData/$(echo $line | awk '{print $1}')" 2>/dev/null)" ]; then
          bindf $line system
        else
          movef $line
          bindf $line system
        fi
      fi
    else
      if ! grep -q "$(echo $line | awk '{print $1}')" $config 2>/dev/null; then
        if [ -n "$(ls "$appData/$(echo $line | awk '{print $1}')" 2>/dev/null)" ]; then
          bindf $line user
        else
          movef $line
          bindf $line user
        fi
      fi
    fi
  done
}


# $1=pkgName
movef() {
  if [ "$2" = "restore" ]; then
    # restore all app data in $appData to /data/data
    for line in $appData/*; do
      rm -rf /data/data/$line 2>/dev/null
      mv -f $appData/$line /data/data/
    done
  else
    # move app data to $appData
    [[ -d $appData ]] || mkdir -p -m 777 $appData
    rm -rf $appData/$1 2>/dev/null
    mv -f /data/data/$1 $appData/
    mkdir -m 777 "/data/data/$1" 2>/dev/null
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
  count=0
  until [ "$count" -ge 360 ]; do
    ((count++))
    grep -q '/mnt/media_rw' /proc/mounts && break || sleep 4
  done
    grep -q '/mnt/media_rw' /proc/mounts && \
      apksBkp="$(ls -1d /mnt/media_rw/* | head -n1)/$modID/apksBkp"
  [[ -d $apksBkp ]] || mkdir -p $apksBkp
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


# restore apks (from terminal)
res_apks() {
  oPATH=$PATH
  PATH=/sbin/.core/busybox:/dev/magisk/bin:$PATH
  echo
  wait4sd
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
  PATH=$oPATH
}


# rollback all app data (from recovery only)
resdata () {
  echo -e "\nMove all app data back to /data/data (y/N) and uninstall adk?"
  read ans
  if echo "$ans" | grep -iq y; then
    echo -e "\nPlease wait...\n"
    movef restore
    [ "$?" -eq "0" ] && rm -rf $mountPoint/adk $modData
  fi
}
