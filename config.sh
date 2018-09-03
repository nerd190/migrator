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
lateStartSvcDATA=false

# Set to true if you need late_start service script
LATESTARTSERVICE=false

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
  for f in $MODPATH/bin/* $MODPATH/system/bin/* $MODPATH/system/xbin/*; do
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


exxit() {
  unmount_magisk_img
  $BOOTMODE || recovery_cleanup
  rm -rf $TMPDIR
  exit $1
}


factory_reset_or_uninstall() {
  if [ "$curVer" -eq "$(i versionCode)" ]; then
    if $BOOTMODE; then
      touch $MOUNTPATH0/$MODID/remove
      ui_print " "
      ui_print "(i) $MODID will be removed at next boot."
      ui_print " "

    else
      migrate_data

      # wipe data
      if grep -q '^wipe' $Config 2>/dev/null; then
        ui_print "- Wiping /data (exc. obvious files/folders)"
        cd /data
        for d in $(ls 2>/dev/null | grep -Ev 'adb|media|misc|system' 2>dev/null); do
          [ -e "$d" ] && rm -rf /data/$d
        done

        cd misc
        for d in $(ls 2>dev/null | grep -v vold); do
          [ -e "$d" ] && rm -rf /data/misc/$d
        done

        cd /data/system
        for d in $(ls 2>dev/null | grep -v storage.xml); do
          [ -e "$d" ] && rm -rf /data/system/$d
        done
      fi
    fi
    ui_print " "
    exxit 0
  fi
}


find_sdcard() {
  if grep -q '/mnt/media_rw' /proc/mounts; then
    Size=0
    for d in /mnt/media_rw/*; do
      newSize="$(df "$d" | tail -n1 | awk '{print $2}')"
      if [ "$newSize" -gt "$Size" ]; then
        Size=$newSize
        sdCard="$d"
      fi
    done
  fi
}


install_module() {
  set_env
  grep -q '^lite' $Config 2>/dev/null && factory_reset_or_uninstall

  # do not support Magisk 16.7 (bugged)
  if [ "$MAGISK_VER_CODE" -eq 1671 ]; then
    # abort installation
	ui_print " "
	ui_print "(!) Magisk 16.7 is officially unsupported!"
	ui_print "- It has some big and scary bugs which love eating several modules' heads."
    ui_print "- Try a newer Magisk version or downgrade to 15.0-16.6."
	ui_print " "
	exxit 1
  fi

  # clean install
  if [ "$curVer" -lt 201808280 -a "$curVer" -ne 0 ]; then
    ui_print " "
    ui_print "(!) Detected legacy version installed!"
    ui_print "- Data must be migrated."
    ui_print "- Uninstall $MODID AND reboot first."
    ui_print " "
    if [ "$MAGISK_VER_CODE" -eq 1671 ]; then
      ui_print "(!) Magisk 16.7 is officially unsupported!"
      ui_print "- It has some big and scary bugs which love eating several modules' heads."
      ui_print "- Install a newer Magisk version or downgrade to 15.0-16.6."
      ui_print " "
    fi
    exxit 1
  fi

  # update config
  [ "$curVer" -lt 201808280 ] \
    && cp -f $INSTALLER/common/config.txt $Config

  # remove obsolete files
  [ "$curVer" -lt 201809030 ] && rm $modData/logs/* $MOUNTPATH0/.core/post-fs-data.d/adk.sh 2>/dev/null

  # create module paths
  { rm -rf $MODPATH
  mkdir -p $MODPATH/bin $modInfo "$lateStartSvcD"; } 2>/dev/null

  # extract module files
  ui_print "- Extracting module files"
  unzip -o "$ZIP" -d $INSTALLER >&2
  cd $INSTALLER
  mv bin/rsync_$binArch $MODPATH/bin/rsync
  mv common/* $MODPATH/
  mv -f $MODPATH/${MODID}.sh "$lateStartSvcD/"
  set +u
  set_perm "$lateStartSvcD/${MODID}.sh" 0 0 755
  set -u
  [ -d /system/xbin ] || mv $MODPATH/system/xbin $MODPATH/system/bin
  mv -f License.md README.md $modInfo/

  # set default config if config.txt is missing
  [ -f "$Config" ] && { rm $MODPATH/config.txt || :; } \
    || mv $MODPATH/config.txt $Config

  set +u
}


migrate_data() {
  if grep -q '^[a-z]' $Config 2>dev/null; then
    ui_print "- Migrating app data"
    awk '{print $1,$2}' $pkgList | \
      while read Line; do
        (if ! [ -d "/data/app/$(pkg_name)-1" -o -d "/data/app/$(pkg_name)-2" ]; then
          # system app
          grep -q "^inc $(pkg_name)" $Config 2>/dev/null && movef $Line
        else
          # treat as user app
          if grep -Eq "^inc $(pkg_name)|^inc$" $Config 2>/dev/null \
            && ! grep -q "^exc $(pkg_name)" $Config 2>/dev/null
          then
            movef $Line
          fi
        fi) &
      done
    wait # for background jobs to finish
  fi
}


# move APK's and respective data to $appData
# $1=pkg_name
movef() {
  mkdir -p $appData
  rm -rf $appData/$1 # remove obsolete data
  mv /data/data/$1 $appData/
  mv /data/app/{$1}*/base.apk $appData/${1}.apk
} 2>/dev/null


pkg_name() { echo "$Line" | awk '{print $1}'; }


# set environment
set_env() {
  set -ux

  modData=/data/media/$MODID
  Config=$modData/config.txt
  modInfo=$modData/info
  magiskDir=$(echo $MAGISKBIN | sed 's:/magisk::')
  utilFunc=$magiskDir/util_functions.sh

  if $BOOTMODE; then
    find_sdcard
    MOUNTPATH0=$(sed -n 's/^.*MOUNTPATH=//p' $utilFunc | head -n1)
  else
    sdCard=/external_sd
    MOUNTPATH0=$MOUNTPATH
  fi

  lateStartSvcD=$MOUNTPATH0/.core/service.d

  curVer="$(grep_prop versionCode $MOUNTPATH0/$MODID/module.prop)"
  set +u
  [ -z "$curVer" ] && curVer=0
  set -u

  # get CPU arch
  case "$ARCH" in
    *86*) binArch=x86;;
    *ar*) binArch=arm;;
  esac
}


version_info() {

  set -u

  ui_print " "
  ui_print "  Facebook Support Page: https://facebook.com/VR25-at-xda-developers-258150974794782/"
  ui_print " "

  whatsNew="- Improved log engine
- Misc enhancements
- Most of 'lite mode' is ready
- Moved ignitor (adk.sh) from post-fs-data.d to service.d
- service.sh merged into adk.sh
- Updated reference"

  ui_print "  WHAT'S NEW"
  echo "$whatsNew" | \
    while read c; do
      ui_print "    $c"
    done
  ui_print "    "

  # a note on untested Magisk versions
  if [ "$MAGISK_VER_CODE" -gt 1671 ]; then
    # abort installation
		ui_print " "
		ui_print "(i) This Magisk version hasn't been tested by @VR25 as of yet."
		ui_print "- Should you find any issue, try a newer Magisk version or downgrade to 15.0-16.6."
    ui_print "- And don't forget to share your experience(s)! ;-)"
		ui_print " "
  fi
}
