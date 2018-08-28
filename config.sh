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
LATESTARTSERVICE=false

##########################################################################################
# Installation Message
##########################################################################################

# Set what you want to show when installing your mod

print_modname() {
  i() { grep_prop $1 $INSTALLER/module.prop; }
  ui_print " "
  ui_print "$(i name) ($(i id)) $(i version)"
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

  set -ux

  modData=/data/media/$MODID
  Config=$modData/config.txt
  modInfo=$modData/info

  if $BOOTMODE; then
    find_sdcard
    MOUNTPATH0=/sbin/.core/img
  else
    sdCard=/external_sd
    MOUNTPATH0=$MOUNTPATH
  fi

  postFsD=$MOUNTPATH0/.core/post-fs-data.d

  curVer="$(grep_prop versionCode $MOUNTPATH0/$MODID/module.prop)"
  set +u
  [ -z "$curVer" ] && curVer=0
  set -u

  # get CPU arch
  case "$ARCH" in
    *86*) binArch=x86;;
    *ar*) binArch=arm;;
  esac

  # upgrade $modData/*
  if [ "$curVer" -lt "201808280" ]; then
    if [ "$curVer" -ne "0" ] && $BOOTMODE && ls "$modData/.appData" 2>/dev/null | grep -q '[a-z]'; then
      echo -e "\n(!) adk can't migrate data while it's in use."
      echo "- No changes were made."
      echo -e "- Upgrade from TWRP.\n"
      unmount_magisk_img
      rm -rf $TMPDIR
      exit 1
    fi
    # migrate data
    ui_print "- Migrating data"
    { cd "$sdCard/adk" && [ -d apksBkp ] && { mkdir backups || :; } && mv -f apksBkp backups/apk
     cd $modData && [ -d apksBkp ] && { mkdir backups || :; } && mv -f apksBkp backups/apk
    mv "$modData/.appData" "$modData/appdata"; } 2>/dev/null
    if [ "$?" = 0 ]; then
      for d in "$modData/appdata"/*; do
        chmod -R 771 "$d" 2>/dev/null
      done
    fi
    cp -f $INSTALLER/common/config.txt $Config
    { rm -rf $modData/logs
    rm $modData/.pending $modData/rollback; } 2>/dev/null
  fi

  # create module paths
  { rm -rf $MODPATH
  mkdir -p $MODPATH/bin $modInfo "$postFsD"; } 2>/dev/null

  # extract module files
  ui_print "- Extracting module files"
  unzip -o "$ZIP" -d $INSTALLER >&2
  cd $INSTALLER
  mv bin/rsync_$binArch $MODPATH/bin/rsync
  mv common/* $MODPATH/
  mv -f $MODPATH/${MODID}.sh "$postFsD/"
  set +u
  set_perm "$postFsD/${MODID}.sh" 0 0 755
  set -u
  [ -d /system/xbin ] || mv $MODPATH/system/xbin $MODPATH/system/bin
  mv -f License.md README.md $modInfo/

  # default config
  [ -f "$Config" ] && { rm $MODPATH/config.txt || :; } \
    || mv $MODPATH/config.txt $Config

  set +u
}


version_info() {

  set -u

  ui_print " "
  ui_print "  Facebook Support Page: https://facebook.com/VR25-at-xda-developers-258150974794782/"
  ui_print " "

  whatsNew="- Protected data and respective APK's are automatically backed up to largest_external_partition/adk/backups (fallback -- /data/media/adk/backups)
- Removed 'rollback' executable (obsolete)
- Support for automatic (scheduled) as well as on-demand incremental backups
- Magisk module template 1500
- Migrate app data to '/data/media/adk/appdata'
- More efficient APK backups
- Restrict app data permissions to 'rwx-rwx-x (771)' 
- Terminal 'adk' wizard
- Updated documentation
- Zillion+ features, fixes and improvements"

  ui_print "  WHAT'S NEW"
  echo "$whatsNew" | \
    while read c; do
      ui_print "    $c"
    done
  ui_print "    "

  grep -q '16\.7' $MAGISKBIN/util_functions.sh \
    && ui_print "  *Note*: a Magisk 16.7 bug causes $MODID to generate empty verbose logs (\"set -x\" doesn't work properly)" \
    && ui_print " "
}
