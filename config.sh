##########################################################################################
#
# Magisk Module Template Config Script
# by topjohnwu
#
##########################################################################################
##########################################################################################
#
# Instructions:
#
# 1. Place your files into system folder (delete the placeholder file)
# 2. Fill in your module's info into module.prop
# 3. Configure the settings in this file (config.sh)
# 4. If you need boot scripts, add them into common/post-fs-data.sh or common/service.sh
# 5. Add your additional or modified system properties into common/system.prop
#
##########################################################################################

##########################################################################################
# Configs
##########################################################################################

# Set to true if you need to enable Magic Mount
# Most mods would like it to be enabled
AUTOMOUNT=true

# Set to true if you need to load system.prop
PROPFILE=false

# Set to true if you need post-fs-data script
POSTFSDATA=false

# Set to true if you need late_start service script
LATESTARTSERVICE=true

##########################################################################################
# Installation Message
##########################################################################################

# Set what you want to show when installing your mod

print_modname() {
  i() { grep_prop $1 $INSTALLER/module.prop; }
  ui_print " "
  ui_print "$(i name) $(i version)"
  ui_print "$(i author)"
  ui_print " "
}

##########################################################################################
# Replace list
##########################################################################################

# List all directories you want to directly replace in the system
# Check the documentations for more info about how Magic Mount works, and why you need this

# This is an example
REPLACE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here, it will override the example above
# !DO NOT! remove this if you don't need to replace anything, leave it empty as it is now
REPLACE="
"

##########################################################################################
# Permissions
##########################################################################################

set_permissions() {
  # Only some special files require specific permissions
  # The default permissions should be good enough for most cases

  # Here are some examples for the set_perm functions:

  # set_perm_recursive  <dirname>                <owner> <group> <dirpermission> <filepermission> <contexts> (default: u:object_r:system_file:s0)
  # set_perm_recursive  $MODPATH/system/lib       0       0       0755            0644

  # set_perm  <filename>                         <owner> <group> <permission> <contexts> (default: u:object_r:system_file:s0)
  # set_perm  $MODPATH/system/bin/app_process32   0       2000    0755         u:object_r:zygote_exec:s0
  # set_perm  $MODPATH/system/bin/dex2oat         0       2000    0755         u:object_r:dex2oat_exec:s0
  # set_perm  $MODPATH/system/lib/libart.so       0       0       0644

  # The following is default permissions, DO NOT remove
  set_perm_recursive  $MODPATH  0  0  0755  0644

  # Permissions for executables
  for f in $MODPATH/bin/* $MODPATH/system/*bin/* $MODPATH/*.sh; do
    [ -f "$f" ] && set_perm $f  0  0  0755
  done
}

##########################################################################################
# Custom Functions
##########################################################################################

# This file (config.sh) will be sourced by the main flash script after util_functions.sh
# If you need custom logic, please add them here as functions, and call these functions in
# update-binary. Refrain from adding code directly into update-binary, as it will make it
# difficult for you to migrate your modules to newer template versions.
# Make update-binary as clean as possible, try to only do function calls in it.


trap 'exxit $? $? 1>/dev/null 2>&1' EXIT


install_module() {

  set -euxo pipefail

  modData=/data/media/$MODID
  migratedData=$modData/migrated_data
  config=$modData/config.txt
  modInfo=$modData/info
  magiskVer=${MAGISK_VER/.}
  pkgList=/data/system/packages.list
  externalStorage=/external_sd
  MOUNTPATH0=$MOUNTPATH
  rsync=$MOUNTPATH/$MODID/bin/rsync
  failedRes=$modData/failed_restores

  if $BOOTMODE; then
    find_sdcard
    MOUNTPATH0=/sbin/.magisk/img
    [ -d $MOUNTPATH0 ] || MOUNTPATH0=/sbin/.core/img
  fi

  iBkps=$modData/backups
  eBkps=$externalStorage/$MODID/backups

  curVer=$(grep_prop versionCode $MOUNTPATH0/$MODID/module.prop || :)
  [ -z "$curVer" ] && curVer=0

  # get CPU arch
  case "$ARCH" in
    *86*) binArch=x86;;
    *ar*) binArch=arm;;
    *) ui_print " "
       ui_print "(!) Unsupported CPU architecture ($ARCH)!"
       ui_print " "
       exxit 1;;
  esac

  [ ! -f /data/.migrator ] && ! $BOOTMODE && factory_reset

  # create module paths
  rm -rf $MODPATH 2>/dev/null || :
  mkdir -p $MODPATH/bin $modInfo

  # extract module files
  ui_print "- Extracting module files"
  unzip -o "$ZIP" -d $INSTALLER >&2
  cd $INSTALLER
  mv bin/rsync_$binArch $MODPATH/bin/rsync
  mv common/* $MODPATH/
  $LATESTARTSERVICE || rm $MODPATH/service.sh
  [ -d /system/xbin ] || mv $MODPATH/system/xbin $MODPATH/system/bin
  mv -f License* README* $modInfo/
  mv $MODPATH/config.txt $MODPATH/default_config.txt

  # set default config
  if [ ! -f $config ] || [ $curVer -lt 201901310 ]; then
    cp -f $MODPATH/default_config.txt $config
  fi

  [ -f /data/.migrator ] && rm /data/.migrator
  set +euxo pipefail
}


migrate_bkps() {
  if [ -d "$iBkps" ]; then
    rm -rf $iBkps.old || :
    mv $iBkps $iBkps.old
  fi
  if [ -d "$eBkps" ]; then
    rm -rf $eBkps.old || :
    mv $eBkps $eBkps.old
  fi
} 2>/dev/null


exxit() {
  set +euxo pipefail
  if [ "x$2" != x0 ]; then
    unmount_magisk_img
    $BOOTMODE || recovery_cleanup
    set -u
    rm -rf $TMPDIR
  fi
  exit $1
}


factory_reset() {
  local d="" e=""
  if [ $curVer -eq $(i versionCode) ]; then
    grep -iq '^noauto' $config 2>/dev/null || migrate_data

    # wipe data
    if ! grep -iq '^nowipe' $config 2>/dev/null; then
      ui_print " "
      ui_print "(i) Wiping data, excluding adb/, media/, misc/(adb/|bluedroid/|vold/|wifi/), ssh/, system.*/(0/accounts.*|storage.xml|sync/accounts.*|users/)) and /cache/magisk*img.."

      for e in $(ls -1A /data 2>/dev/null \
        | grep -Ev '^adb$|^data$|^media$|^misc$|^system|^ssh$' 2>/dev/null)
      do
        (rm -rf /data/$e) &
      done

      for e in $(ls -1A /data/data 2>/dev/null \
        | grep -Ev 'provider' 2>/dev/null)
      do
        (rm -rf /data/data/$e) &
      done

      for e in $(ls -1A /data/misc 2>/dev/null | grep -Ev '^adb$|^bluedroid$|^vold$|^wifi$' 2>/dev/null)
      do
        (rm -rf /data/misc/$e) &
      done

      for e in $(ls -1A /data/system* 2>/dev/null \
        | grep -Ev '^/.*:$|^0$|^sync$|^storage.xml$|^users$' 2>/dev/null)
      do
        (rm -rf /data/system*/$e 2>/dev/null) &
      done

      for e in $(ls -1A /data/system/sync 2>/dev/null \
        | grep -v '^accounts.xml$' 2>/dev/null)
      do
        (rm -rf /data/system/sync/$e) &
      done

      for e in $(ls -1A /data/system*/0 2>/dev/null \
        | grep -Ev '^/.*:$|^accounts.*db$|^accounts.*al$' 2>/dev/null)
      do
        (rm -rf /data/system*/0/$e 2>/dev/null) &
      done

      for d in $(find /data/system/users -type d -name registered_services 2>/dev/null); do
        (rm -rf $d) &
      done

      if mount -o remount,rw /cache 2>/dev/null; then
        for e in $(ls -1A /cache 2>/dev/null | grep -v '^magisk*img$' 2>/dev/null); do
          (rm -rf /cache/$e) &
        done
      fi

      wait
    fi
    ui_print " "
    exxit 0
  fi
}


find_sdcard() {
  local d="" size=0 newSize=0
  if grep -q '/mnt/media_rw' /proc/mounts; then
    for d in /mnt/media_rw/*; do
      newSize=$(df "$d" | tail -n 1 | awk '{print $2}')
      if [ "$newSize" -gt "$size" ]; then
        size=$newSize
        externalStorage="$d"
      fi
    done
  fi
}


migrate_data() {
  local pkg=""
  if grep -q '^inc' $config 2>/dev/null; then
    ui_print " "
    ui_print "(i) Migrating apps.."
    set +e
    { rm -rf $failedRes.old $migratedData.old
    mv $failedRes $failedRes.old
    mv $migratedData $migratedData.old; } 2>/dev/null
    set -e
    awk '{print $1}' $pkgList | \
      while read pkg; do
        (pkg=$pkg # make sure value doesn't change until subshell exits
        if ! ls -p /data/app/$pkg* 2>/dev/null | grep -q /; then
          # system app
          match_test inc $pkg && migrate_apk_plus_data
        else
          # user app
          if { grep -q '^inc$' $config || match_test inc $pkg; } \
            && ! match_test exc $pkg \
            && ! grep $pkg /data/system/packages.xml | grep -q '/system/.*app/'
          then
            migrate_apk_plus_data
          fi
        fi) &
      done
    migrate_bkps
    wait
  fi
}


# migrate APKs and respective data to $migratedData
migrate_apk_plus_data() {
  mkdir -p $migratedData $migratedData
  bkp_symlinks
  mv /data/data/$pkg $migratedData/
  set +eo pipefail
  grep $pkg /data/system/packages.xml | grep -q '/system/.*app/' \
    || mv $(find /data/app/$pkg* type f -name base.apk 2>/dev/null | head -n 1) \
      $migratedData/$pkg.apk 2>/dev/null
  set -eo pipefail
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


bkp_symlinks() {
  local l="" lns=$migratedData/$pkg.lns
  : >$lns
  for l in $(find /data/data/$pkg -type l); do
    echo "$(readlink -f $l | sed "s:$pkg.*/lib/[^/]*:$pkg\*/lib/\*:; s:$pkg.*/lib/:$pkg\*/lib/:") $l" >>$lns
  done
  grep -q '^/' $lns || rm $lns
}


version_info() {
  local line=""
  local println=false

  # a note on untested Magisk versions
  if [ ${MAGISK_VER/.} -gt 180 ]; then
    ui_print " "
    ui_print "  (i) NOTE: this Magisk version hasn't been tested by @VR25!"
    ui_print "    - If you come across any issue, please report."
  fi

  ui_print " "
  ui_print "  WHAT'S NEW"
  cat ${config%/*}/info/README.md | while read line; do
    echo "$line" | grep -q '\*\*.*\(.*\)\*\*' && println=true
    $println && echo "$line" | grep -q '^$' && break
    #$println && ui_print "$(echo "    $line" | grep -v '\*\*.*\(.*\)\*\*')"
    $println && echo "    $line" | grep -v '\*\*.*\(.*\)\*\*' >> /proc/self/fd/$OUTFD
  done
  ui_print " "

  ui_print "  LINKS"
  ui_print "    - Donation: https://paypal.me/vr25xda/"
  ui_print "    - Facebook page: facebook.com/VR25-at-xda-developers-258150974794782/"
  ui_print "    - Git repository: github.com/Magisk-Modules-Repo/adk/"
  ui_print "    - Telegram channel: t.me/vr25_xda/"
  ui_print "    - Telegram profile: t.me/vr25xda/"
  ui_print "    - XDA thread: forum.xda-developers.com/apps/magisk/magisk-module-app-data-keeper-adk-t3822278/"
  ui_print " "
}
