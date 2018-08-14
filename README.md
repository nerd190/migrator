# App Data Keeper (adk)
## Copyright (C) 2018, VR25 @ xda-developers
### License: GPL v3+



#### DISCLAIMER

- This software is provided as is, in the hope that it will be useful, but without any warranty. Always read the reference prior to installing/updating. While no cats have been harmed, I assume no responsibility under anything that might go wrong due to the use/misuse of it.
- A copy of the GNU General Public License, version 3 or newer ships with every build. Please, read it prior to using, modifying and/or sharing any part of this work.
- To prevent fraud, DO NOT mirror any link associated with this project.



#### DESCRIPTION

- By default, standard Android factory reset methods wipe "everything" inside /data/data. This can be frustrating for many, as it implies having to set things up entirely from scratch after flashing new ROM's and/or advanced mods/tweaks. I don't know of anyone who likes doing such a repetitive and tiring task, nor I believe that kind of person even exists. Well, unless they have hardcore OCD. Still, I think even such an individual would be frustrated to death at some point (jokes aside). Speaking of repetition and tiredness, Titanium Backup and alike are slow solutions when compared to adk. Besides app data being already in place, adk uses rsync to backup APK's. If you don't know how powerful rsync is, look that up. Last, but not least, the module ships with a terminal tool (`adk`) to batch restore APK's after factory resets.
- Apps' data is moved to /data/media/adk/.appData, then bind-mounted to the original locations. This is done in post-fs-data mode for maximum efficiency. If somehow, a target APK is missing on the next boot, then the bind-mounting of its data does not occur. This prevents system from removing it.
- In late start service mode, APKs's are automatically sync'ed to `$(ls -1d /mnt/media_rw/* | head -n1)/adk/apksBkp` (external storage) if found (or else, to `/data/media/adk/apksBkp`). Thanks to rsync's delta algorithm, only changed parts of APK's are copied. Talk about efficiency...



#### PRE-REQUISITES

- Magisk
- Terminal emulator app (for restoring APK's)



#### CONFIG


Config file: /data/media/adk/config.txt


Syntax:

  inc --> include all user and *updated* system packages data

  inc pkgName --> include pkgName (user or any system package data)

  exc pkgName --> exclude *user* pkgName data (overrides "inc" and "inc pkgName")

  NOTHING (null/empty config) --> exclude all (default)


Example 1 -- all user and *updated* system packages data, except Spotify's:

    `inc

    exc com.spotify music`


Example 2 -- only Android Keyboard (AOSP) data

    `inc com.android.inputmethod.latin` (non-update-able system app)


Example 3 -- Android Keyboard (AOSP) and all user & *updated* system packages data, except Spotify's:

    `inc`

    `inc com.android.inputmethod.latin` (non-update-able system apps are not affected by a bare "inc")

    `exc com.spotify music`


Example 4: all user and *updated* system packages data, except *updated* Google Play Services:

    `inc`

    `exc com.google.android.gms` (updated system packages are treated as user apps -- affected by a bare "inc")



#### SETUP STEPS

*Note*: keep backing up your user and updated system apps' data until you feel comfortable using adk.

- First Time
1. Install adk from Magisk Manager or TWRP.
2. Set up config.txt
3. Reboot
3. 1. *Reboot again if you find any issue*
4. Forget.

- After a Factory Reset
1. Install adk from Magisk Manager or TWRP.
2. Reboot.
3. Locate your favorite backed up terminal app in `[external storage]/adk/apksBkp` or `/data/media/adk/apksBkp` and install it.
4. Run the command `adk`, type `.` (that's a dot), press the enter key and wait. This will automatically reinstall all backed up APKs.
5. Reboot.
5.1. *Reboot again if you find any issue*
6. Forget.



#### DEBUGGING & ADVANCED INFO

- logsDir: /data/media/adk/logs
- Updated system apps are treated as user apps.
- While in recovery and after flashing the module, the command `adk` is available for *rolling back all changes* and completely uninstalling adk.
- If you find any issue after installing/updating, *rebooting again* may fix the problem.
- If the module is disabled or removed, apps' data is automatically moved back to /data/data.



#### LINKS

- [Facebook Support Page](https://facebook.com/VR25-at-xda-developers-258150974794782)
- [Git Repository](https://github.com/Magisk-Modules-Repo/App-Data-Keeper)
- [XDA Thread](https://forum.xda-developers.com/apps/magisk/magisk-module-app-data-keeper-adk-t3822278)



#### LATEST CHANGES

**2018.8.15 (201808150)**
- Auto-move apps' data back to /data/data if adk is disabled/removed
- "Exclude all" mode set by default (check the README for details)
- General fixes and optimizations
- Move post-fs-data.sh to .core/post-fs-data.d for efficiency++"
- Updated debugging tools & documentation

**2018.8.14 (201808140)**
- Fixed install failure from MM (Android P, Magisk 16.7)
- Major optimizations for greater efficiency
- Simplified code documentation
- Updated reference and module description

**2018.8.13 (201808130)**
- Backup APK's more efficiently
- Fixed "parameter not set", leading to APK's not being backed up, and other issues
  *Release note*: a Magisk 16.7 bug causes adk to generate empty logs (set -x doesn't work properly)
