# App Data Keeper (adk)
## Copyright (C) 2018, VR25 @ xda-developers
### License: GPL v3+



---
#### DISCLAIMER

This software is provided as is, in the hope that it will be useful, but without any warranty. Always read the reference prior to installing/updating. While no cats have been harmed, I assume no responsibility under anything that might go wrong due to the use/misuse of it.

A copy of the GNU General Public License, version 3 or newer ships with every build. Please, read it prior to using, modifying and/or sharing any part of this work.

To prevent fraud, DO NOT mirror any link associated with this project.



---
#### DESCRIPTION

At the time of this writing, by default, a standard TWRP wipe (factory reset) obliterates everything in /data/data, except media, misc/vold and system/storage.xml.

This module protects select apps' data from being wiped out. Thus, greatly reducing the amount of time required for setting up a new system.

Additionally, adk is a full backup solution, thanks to rsync and OpenSSH capabilities. Protected data and respective APK's are automatically backed up.

Bonus: TWRP boot time and backup sizes are greatly reduced when a significant amount of app data is protected.



---
#### PRE-REQUISITES

- Magisk v15+
- Terminal emulator



---
#### CONFIG


Config file: /data/media/adk/config.txt


SYNTAX

  Incremental apps' data backup frequency in hours (value must be an integer, default: 8)
  
      bkpFreq=8

  Include all user and *updated* system apps
      inc

  Include pkgName (this works for any app, and it's the only way to *include non-update-able system apps*)
  
      inc pkgName

  Exclude *user* app (overrides "inc" and "inc pkgName")
  
      exc pkgName

  Advanced incremental, scheduled backups (rsync -rtu --inplace $bkp_line)
  
      bkp [extra rsync option(s)] [SOURCE(s)] [DEST]
    
    Tip: use $i for internal storage and $e for external media (largest partition) as opposed to writing full paths.
    
    For rsync-specific details, refer to its man page.


EXAMPLES

  App data protection setups

    All user and *updated* system apps, except Spotify
    
      inc
      
      exc com.spotify music

    Only Android Keyboard (AOSP) (a non-update-able system app)
    
      inc com.android.inputmethod.latin

    Android Keyboard (AOSP) and all user & *updated* system apps, except Spotify
    
      inc
      
      inc com.android.inputmethod.
      
      exc com.spotify music

    All user and *updated* system apps, except *updated* Google Play Services
    
      inc
      
      exc com.google.android.gms

  Backup setups
  
    Full internal storage
    
      bkp --del $i/ $e/full_internal_bkp
    
    Specific data
    
      bkp --del $i/Download $i/Dukto $e/important_data
    
    Some data to some remote machine
    
      bkp -e "ssh -i /path/to/key" SOURCE user@host:DESTINATION
    
    Sync all backed up apps and respective data to a remote machine

      bkp -e "ssh -i /path/to/key" $appBkps $appdataBkps user@host:DESTINATION

    
NOTES

  A bare "inc" affects user and updated system apps only.
  
  An empty/null config disables all features. If data protection was enabled, app data is automatically moved back to /data/data on the next boot. Data is also automatically restored the next boot after adk is disabled/uninstalled.

  Only inc'd (included) apps are backed up.

  Updated system apps are treated as user apps.

  Valid config lines have no leading nor trailing pounds/spaces and/or any other additionall characters.


DEFAULT CONFIG

  inc
  


---
#### TERMINAL

Running `adk` as root launches "adk wizard". Included options are incremental backups, data restore, and more.



---
#### SETUP STEPS

**WARNING**: make sure you have recent backups of your apps' data before enabling adk's app data protection feature. Good backup is not a single backup. If you take backups seriously, then you have multiple copies of your data in different locations. If something goes wrong, either because "reasons" or you forgot to feed your cat beforehand, AND you don't have a backup, do NOT curse me! Also, NEVER "downgrade" directly; uninstall and reboot first.

- First Time
1. Install adk from Magisk Manager or TWRP.
2. Customize your config.txt (optional)
3. Reboot. *Reboot again if you find any issue*.
4. Forget.

- After a Factory Reset
1. Install adk from Magisk Manager or TWRP.
2. Reboot.
3. Locate your favorite backed up terminal app in `[external storage]/adk/backups/apk` or `/data/media/adk/backups/apk` and install it.
4. Run the command `adk` and follow the wizard to restore backed up apps and respective data.
5. Reboot. *Reboot again if you find any issue*.
6. Forget.



---
#### DEBUGGING & ADVANCED INFO

Apps are disabled before data restore and re-enabled afterwards.

bkpFreq for "bkp [extra rsync option(s)] [SOURCE(s)] [DEST]" is $((bkpFreq + 3600)). That is, one hour after the set value. This prevents conflicts with bkp_appdata().

How does this data protection thing actually work? At a glance, adk moves select apps' data to /data/media/adk/appdata before system services start. Next, it bind-mounts moved folders to their original locations. Thus, apps are fooled into "believing" their data is still in /data/media. Of course, this is an overly simplified explanation. Refer to the source code for extensive info.

logsDir: /data/media/adk/logs

SELinux mode is set to "permissive" for compatibility.

When external storage is detected, adk uses the largest partition for backups.



---
#### LINKS

- [Facebook Support Page](https://facebook.com/VR25-at-xda-developers-258150974794782)
- [Git Repository](https://github.com/Magisk-Modules-Repo/App-Data-Keeper)
- [XDA Thread](https://forum.xda-developers.com/apps/magisk/magisk-module-app-data-keeper-adk-t3822278)



---
#### LATEST CHANGES

**2018.8.28 (201808280)**
- Protected data and respective APK's are automatically backed up to largest_external_partition/adk/backups (fallback -- /data/media/adk/backups)
- Removed 'rollback' executable (obsolete)
- Support for automatic (scheduled) as well as on-demand incremental backups
- Magisk module template 1500
- Migrate app data to '/data/media/adk/appdata'
- More efficient APK backups
- Restrict app data permissions to 'rwx-rwx-x (771)' 
- Terminal 'adk' wizard
- Updated documentation
- Zillion+ features, fixes and improvements

**2018.8.18 (201808180)**
- Auto-update app data ownership (compatibility)
- Enhanced module uninstaller, parallel processing and APK restorer
- Major optimizations
- Updated documentation (as always, read it!)
- Parse `package.list` instead of `packages.xml` (efficiency)

**2018.8.16 (201808160)**
- Added option to remove all uninstalled APK's from backup folder (`adk -r`)
- cp uninstaller (rollback) to /data/media/adk
- Default config.txt includes a set up tutorial
- Fixed "duplicate/orphan APK's in backup folder" (rsync --partial)
- Misc optimizations
- More advanced and user-friendly APK restore wizard
- New and blazing fast batch APK restore algorithm
- Set SELinux mode to "permissive" for more compatibility
- Updated documentation (please [re]read it)
