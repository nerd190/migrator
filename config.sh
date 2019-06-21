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
POSTFSDATA=true

# Set to true if you need late_start service script
LATESTARTSERVICE=true

##########################################################################################
# Installation Message
##########################################################################################

# Set what you want to show when installing your mod

print_modname() {
  ui_print " "
  ui_print "$name  $version"
  ui_print "$author"
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


install_module() {

  set -euxo pipefail
  trap 'exxit $?' EXIT

  leaveImgMounted=false
  modData=/data/media/$MODID
  migratedData=$modData/migrated_data
  config=$modData/config.txt
  modInfo=$modData/info
  magiskVer=${MAGISK_VER/.}
  pkgList=/data/system/packages.list
  MOUNTPATH0=$MOUNTPATH
  failedRes=$modData/failed_restores

  if $BOOTMODE; then
    MOUNTPATH0=/sbin/.magisk/img
    [ -d $MOUNTPATH0 ] || MOUNTPATH0=/sbin/.core/img
  fi

  currVer=$(grep_prop versionCode $MOUNTPATH0/$MODID/module.prop || echo 0)

  # get CPU arch
  case "$ARCH" in
    *86*) binArch=x86;;
    *arm*) binArch=arm;;
    *) ui_print "(!) rsync_$ARCH binary is not included!"
        binArch=dummy;;
  esac

  [ ! -f /data/.migrator ] && ! $BOOTMODE && factory_reset

  # create module paths
  rm -rf $MODPATH 2>/dev/null || :
  mkdir -p $MODPATH/bin $modInfo
  [ -d /system/xbin ] && mkdir -p $MODPATH/system/xbin \
    || mkdir -p $MODPATH/system/bin

  # extract module files
  ui_print "- Extracting module files"
  unzip -o "$ZIP" -d $INSTALLER >&2
  cd $INSTALLER
  mv bin/rsync_$binArch $MODPATH/bin/rsync
  mv common/* $MODPATH/
  ! $POSTFSDATA || cp -l $MODPATH/service.sh $MODPATH/post-fs-data.sh
  $LATESTARTSERVICE || rm $MODPATH/service.sh
  mv $MODPATH/migrator $MODPATH/system/*bin/
  cp -l $MODPATH/system/*bin/migrator $(echo $MODPATH/system/*bin)/M
  mv -f License* README* $modInfo/

  # patch/set config
  set +e
  if [ -f $config ] && [ 0$(grep_prop versionCode $config) -lt 0201903250 ]; then
    rm $config.old* 2>/dev/null
    mv $config $config.old 2>/dev/null
    cp -f $MODPATH/default_config.txt $config
  fi

  rm /data/.migrator 2>/dev/null
  set +uxo pipefail
}


exxit() {
  set +euxo pipefail
  if [ $1 -ne 0 ]; then
    unmount_magisk_img
    $BOOTMODE || recovery_cleanup
    set -u
    rm -rf $TMPDIR
  fi 2>/dev/nul 1>&2
  if $leaveImgMounted; then
    mount -o rw /
    mkdir -p /M
    mount /data/adb/magisk.img /M 2>/dev/null
  fi
  echo
  echo "***EXIT $1***"
  echo
  exit $1
} 1>&2


factory_reset() {
  local d="" line=""
  if [ $currVer -eq $versionCode ]; then
    grep -iq '^noPkgMigration' $config 2>/dev/null || migrate

    # wipe data
    if ! grep -iq '^noAutoWipe' $config 2>/dev/null; then
      leaveImgMounted=true
      ui_print "- Wiping /data..."

      for target in $(ls -1A /data 2>/dev/null \
        | grep -Ev '^adb$|^data$|^media$|^misc$|^system|^ssh$|^user' 2>/dev/null)
      do
        rm -rf /data/$target
      done

      for target in $(ls -1A /data/user*/* 2>/dev/null \
        | grep -Ev '^/.*:$|\.provider|\.bookmarkprovider' 2>/dev/null)
      do
        rm -rf /data/data/$target
      done

      for target in $(ls -1A /data/user*/*/*.bookmarkprovider 2>/dev/null \
        | grep -Ev '^/.*:$|/databases/' 2>/dev/null)
      do
        rm -rf /data/user*/*/*.bookmarkprovider/$target
      done

      for target in $(ls -1A /data/user*/*/*.provider* 2>/dev/null \
        | grep -Ev '^/.*:$|/databases/' 2>/dev/null)
      do
        rm -rf /user*/*/*.provider*/$target
      done

      for target in $(ls -1A /data/misc 2>/dev/null \
        | grep -Ev '^adb$|^bluedroid$|^vold$|^wifi$' 2>/dev/null)
      do
        rm -rf /data/misc/$target
      done

      for target in $(ls -1A /data/system* 2>/dev/null \
        | grep -Ev '^/.*:$|^[0-99]$|^sync$|^storage.xml$|^users$' 2>/dev/null)
      do
        rm -rf /data/system*/$target
      done

      for target in $(ls -1A /data/system/sync 2>/dev/null \
        | grep -v '^accounts.xml$' 2>/dev/null)
      do
        rm -rf /data/system/sync/$target
      done

      for target in $(ls -1A /data/system*/[0-99] 2>/dev/null \
        | grep -Ev '^/.*:$|^accounts.*db.*' 2>/dev/null)
      do
        rm -rf /data/system*/[0-99]/$target
      done

      for target in $(find /data/system/users \
        -type d -name registered_services 2>/dev/null)
      do
        rm -rf $target
      done

      set +eo pipefail

      # disable <module ID>
      grep '^disable' $config 2>/dev/null | while IFS= read -r line; do
        echo $line | grep -q disable.. && eval 'touch $MOUNTPATH/$(echo $line | sed 's/^disable//') 2>/dev/null'
      done

      # remove <paths>
      grep '^remove' $config 2>/dev/null | while IFS= read -r line; do
        echo $line | grep -q remove.. && eval 'rm -rf $(echo $line | sed 's/^remove//') 2>/dev/null'
      done

    fi

    # script for fixing bootloop and other issues
    cd $INSTALLER
    unzip -o "$ZIP" common/M -d $INSTALLER >&2
    mv -f common/M /data/
    exxit 0
  fi
}


migrate() {
  local pkg="" thread=0
  local threads=$(( $(sed -n 's/^threads=//p' $config) - 1 )) || :
  if grep -q '^inc ' $config 2>/dev/null; then
    ui_print "- Migrating apps+data (using $((threads + 1)) threads)..."
    set +e
    { rm -rf $failedRes.old $migratedData.old
    mv $failedRes $failedRes.old
    mv $migratedData $migratedData.old; } 2>/dev/null
    mkdir -p $migratedData
    set -e
    for pkg in $(awk '{print $1}' $pkgList); do
      [ $thread -gt $threads ] && { wait; thread=0; }
      if ! grep "\"$pkg\" codePath" /data/system/packages.xml | grep -q 'codePath=\"/data/'; then
        if match_test inc $pkg && ! match_test exc $pkg; then
          thread=$(( thread + 1 )) || :
          (pkg=$pkg; apps_and_data) &
        fi
      else
        if ! match_test exc $pkg; then
          if grep -q '^inc --user' $config || match_test inc $pkg; then
            thread=$(( thread + 1 )) || :
            (pkg=$pkg; apps_and_data) &
          fi
        fi
      fi
    done
    wait
  fi
}


apps_and_data() {
  ui_print "  - $pkg"
  mv /data/data/$pkg $migratedData/
  set +eo pipefail
  ! grep "\"$pkg\" codePath" /data/system/packages.xml | grep -q 'codePath=\"/data/' \
    || mv $(grep "\"$pkg\" codePath" /data/system/packages.xml | awk '{print $3}' \
      | sed 's/codePath="//;s/"//')/base.apk $migratedData/$pkg.apk 2>/dev/null
  set -eo pipefail
}


# $1 -- <inc or exc>
# $2 -- <package name>
match_test() {
  local target=""
  for target in $(sed -n "s/^$1 //p" $config); do
    echo $2 | grep -Eq "$target" 2>/dev/null && return 0 || :
  done
  return 1
}


print() { grep_prop $1 $INSTALLER/module.prop; }


version_info() {
  local line=""
  local println=false

  # a note on untested Magisk versions
  if [ ${MAGISK_VER/.} -gt 181 ]; then
    ui_print " "
    ui_print "  (i) NOTE: this Magisk version hasn't been tested by @VR25!"
    ui_print "    - If you come across any issue, please report."
  fi

  ui_print " "
  ui_print "  WHAT'S NEW"
  cat ${config%/*}/info/README.md | while IFS= read -r line; do
    if $println; then
      echo "$line" | grep -q '^$' && break \
        || { line="$(echo "    $line")" && ui_print "$line"; }
    else
      echo "$line" | grep -q \($versionCode\) && println=true
    fi
  done
  ui_print " "

  ui_print "  LINKS"
  ui_print "    - Donate: https://paypal.me/vr25xda/"
  ui_print "    - Facebook page: facebook.com/VR25-at-xda-developers-258150974794782/"
  ui_print "    - Git repository: github.com/Magisk-Modules-Repo/migrator/"
  ui_print "    - Telegram channel: t.me/vr25_xda/"
  ui_print "    - Telegram group: t.me/migrator_magisk/"
  ui_print "    - Telegram profile: t.me/vr25xda/"
  ui_print "    - XDA thread: forum.xda-developers.com/apps/magisk/magisk-module-app-data-keeper-adk-t3822278/"
  ui_print " "
}


author=$(print author)
name=$(print name)
version=$(print version)
versionCode=$(print versionCode)
unset -f print
