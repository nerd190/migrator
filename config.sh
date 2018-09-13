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


# exit trap (debugging tool)
debug_exit() {
  echo -e "\n***EXIT $?***\n"
  set +euxo pipefail
  set
  echo
  echo "SELinux status: $(getenforce 2>/dev/null || sestatus 2>/dev/null)" \
    | sed 's/En/en/;s/Pe/pe/'
} >&2
trap debug_exit EXIT


install_module() {

  prep_environment

  # force reinstall if file exists (debugging)
  [ -f /data/.adk ] || factory_reset_or_uninstall

  # do not support flawed Magisk versions
  if echo $magiskVer | grep -Eq '167|170|171' && [ ! -f /data/.adk ]; then
    ui_print " "
    ui_print "(!) Magisk $MAGISK_VER is officially unsupported!"
    ui_print "- It has some big and scary bugs which love eating several modules' heads."
    ui_print "- Try a newer Magisk version or downgrade to 15.0-16.6."
    ui_print "- Or run 'touch /data/.adk' to override, a.k.a., install $MODID anyway (for debugging purposes only)."
    ui_print " "
    exxit 1
  fi

  # block direct downgrade
  if [ "$curVer" -gt "$(i versionCode)" ]; then
    ui_print " "
    ui_print "(!) Direct downgrade is forbidden!"
    ui_print "- Uninstall AND reboot into system first."
    ui_print " "
    exxit 1
  fi

  # block direct legacy upgrade
  if [ "$curVer" -lt 201809130 -a "$curVer" -ne 0 ] \
    && ls $modData/.appData $modData/appdata 2>/dev/null | grep -q .
  then
    ui_print " "
    ui_print "(!) Detected legacy version installed!"
    ui_print "- Apps data must be migrated."
    ui_print "- Uninstall $MODID AND reboot into system first."
    ui_print " "
    exxit 1
  fi

  # update config & remove obsolete files
  if [ "$curVer" -lt 201809130 ]; then
    cp -f $INSTALLER/common/config.txt $Config
    rm $modData/logs/* \
      $MOUNTPATH0/.core/post-fs-data.d/adk.sh \
      $MOUNTPATH0/.core/service.d/adk.sh 2>/dev/null || true
  fi

  # create module paths
  rm -rf $MODPATH 2>/dev/null || true
  mkdir -p $MODPATH/bin $modInfo

  # extract module files
  ui_print "- Extracting module files"
  unzip -o "$ZIP" -d $INSTALLER >&2
  cd $INSTALLER
  mv bin/rsync_$binArch $MODPATH/bin/rsync
  mv common/* $MODPATH/
  [ -d /system/xbin ] || mv $MODPATH/system/xbin $MODPATH/system/bin
  mv -f License* README* $modInfo/
  cp $MODPATH/config.txt $MODPATH/default_config.txt

  # set default config if $Config is missing
  [ -f "$Config" ] && rm $MODPATH/config.txt \
    || mv $MODPATH/config.txt $Config

  [ -f /data/.adk ] && rm /data/.adk
  set +euxo pipefail
}


migrate_bkps() {
  if [ -d "$iBkps" ]; then
    rm -rf $iBkps.old || true
    mv $iBkps $iBkps.old
  fi
  if [ -d "$eBkps" ]; then
    rm -rf $eBkps.old || true
    mv $eBkps $eBkps.old
  fi
} 2>/dev/null


exxit() {
  set +euxo pipefail
  unmount_magisk_img
  $BOOTMODE || recovery_cleanup
  set -u
  rm -rf $TMPDIR
  exit $1
}


factory_reset_or_uninstall() {
  local d e
  if [ "$curVer" -eq "$(i versionCode)" ]; then
    if $BOOTMODE; then
      touch $MOUNTPATH0/$MODID/remove
      ui_print " "
      ui_print "(i) $MODID will be removed at next boot."

    else
      set +e
      grep -q noauto $Config 2>/dev/null || migrate_data
      set -e

      # wipe data
      if grep -q '^wipe$' $Config 2>/dev/null; then
        ui_print " "
        ui_print "(i) Wiping /data (exc. adb/, media/, misc/(adb/|vold/|wifi/), ssh/ and system(""|.*)/(0/accounts.*|storage.xml|sync/accounts.*|users/))..."

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

        for e in $(ls -1A /data/misc 2>/dev/null | grep -Ev '^adb$|^vold$|^wifi$' 2>/dev/null)
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
          rm -rf $d
        done

        wait
        ui_print "- Done."
      fi

      ui_print "- You apps+data will be automatically restored shortly after boot."
    fi
    ui_print " "
    exxit 0
  fi
}


find_sdcard() {
  local d Size newSize
  if grep -q '/mnt/media_rw' /proc/mounts; then
    Size=0
    for d in /mnt/media_rw/*; do
      newSize=$(df "$d" | tail -n 1 | awk '{print $2}')
      if [ "$newSize" -gt "$Size" ]; then
        Size=$newSize
        externalStorage="$d"
      fi
    done
  fi
}


migrate_data() {
  local Pkg
  if grep -Eq '^inc$|^inc ' $Config 2>/dev/null; then
    ui_print " "
    ui_print "(i) Migrating data..."
    set +e
    { rm -rf $failedRes.old $migratedData.old
    mv $failedRes $failedRes.old
    mv $migratedData $migratedData.old; } 2>/dev/null
    set -e
    awk '{print $1}' $pkgList | \
      while read Pkg; do
        (if ! ls -p /data/app/$Pkg* 2>/dev/null | grep -q /; then
          # system app
          match_test inc $Pkg && migrate_apk_plus_data
        else
          # treat as user app
          if { grep -q '^inc$' $Config || match_test inc $Pkg; } \
            && ! match_test exc $Pkg
          then
            migrate_apk_plus_data
          fi
        fi) &
      done
    migrate_bkps
    wait # for background jobs to finish
    ui_print "- Done."
  fi
}


# migrate APK's and respective data to $migratedData
migrate_apk_plus_data() {
  mkdir -p $migratedData
  mv /data/data/$Pkg $migratedData/
  set +eo pipefail
  mv $(find /data/app/$Pkg* type f -name base.apk 2>/dev/null | head -n 1) \
    $migratedData/$Pkg.apk 2>/dev/null
  set -eo pipefail
}


prep_environment() {

  # shell behavior
  set -o errexit # set -e
  set -o nounset # set -u
  set -o pipefail
  set -o xtrace # set -x
  #IFS=$'\n\t' # new line & tab
  #umask 000 # default perms (d=rwx-rwx-rwx, f=rw-rw-rw)

  modData=/data/media/$MODID
  migratedData=$modData/migrated_data
  Config=$modData/config.txt
  modInfo=$modData/info
  utilFunc=$MAGISKBIN/util_functions.sh
  magiskVer=${MAGISK_VER/.}
  pkgList=/data/system/packages.list
  externalStorage=/external_sd
  MOUNTPATH0=$MOUNTPATH
  rsync=$MOUNTPATH/$MODID/bin/rsync
  failedRes=$modData/failed_restores

  if $BOOTMODE; then
    find_sdcard
    MOUNTPATH0=$(sed -n 's/^.*MOUNTPATH=//p' $utilFunc | head -n 1)
  fi

  iBkps=$modData/backups
  eBkps=$externalStorage/$MODID/backups

  curVer=$(grep_prop versionCode $MOUNTPATH0/$MODID/module.prop || true)
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


version_info() {

  local c
  set -euxo pipefail

  ui_print " "
  ui_print "  Facebook Support Page: https://facebook.com/VR25-at-xda-developers-258150974794782/"
  ui_print " "

  whatsNew="- Ability to change where to restore backups from.
- Backups of uninstalled apps can be removed selectively.
- Blacklisted Magisk versions 17.0 and 17.1 in addition to 16.7 (adk will refuse to install; run 'touch /data/.adk' to override).
- Block direct downgrade and direct legacy upgrade.
- Cleaner design
- Config keywords 'inc' and 'exc' work with globbing/regex patterns.
- Improved backup/restore algorithms.
- Migrate apps+data before factory reset & auto-restore everything shortly after boot (unless 'noauto' config keyword is set).
- Misc fixes & optimizations
- No more on-boot data moving nor bind-mounting.
- Option to run all scheduled backups on demand (adk wizard, 4).
- Removed standalone post-fs-data.d/adk.sh in favor of \$modPath/service.sh.
- Save a copy of the default config.txt to \$MODPATH & automatically restore it whenever $Config is missing.
- Save temp files to a non-persistent dir (/dev/adk_tmp).
- SELinux mode is no longer altered.
- Updated documentation & debugging constructs/tools (new log formats, better error reporting & handling, and more).
- When the 'wipe' feature is enabled, all Magisk modules, plus adb keys, ssh config & keys and a bunch of other system data (i.e., accounts, contacts, SMSs/MMSs, call logs, saved Wi-Fi networks, settings, etc.) also survive factory resets."

  ui_print "  WHAT'S NEW"
  echo "$whatsNew" | \
    while read c; do
      ui_print "    $c"
    done
  # Install note
  if [ "$curVer" -lt 201809130 ]; then
    ui_print " "
    ui_print "  Install note: $Config was overwritten (new info)."
  fi
  ui_print " "

  # a note on untested Magisk versions
  if [ "$magiskVer" -gt 167 ]; then
    ui_print " "
    ui_print "(i) This Magisk version hasn't been tested by @VR25 as of yet."
    ui_print "- Should you find any issue, try a newer Magisk version or downgrade to 15.0-16.6."
    ui_print "- And don't forget to share your experience(s)! ;-)"
    ui_print " "
  fi
}
