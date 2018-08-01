# App Data Keeper (adk) 
## (c) 2018, VR25 @ xda-developers
### License: GPL v3+



#### DISCLAIMER

- This software is provided as is, in the hope that it will be useful, but without any warranty. Always read the reference prior to installing/updating. While no cats have been harmed, I assume no responsibility under anything that might go wrong due to the use/misuse of it.
- A copy of the GNU General Public License, version 3 or newer ships with every build. Please, read it prior to using, modifying and/or sharing any part of this work.
- To prevent fraud, DO NOT mirror any link associated with this project.



#### DESCRIPTION

- By default, standard Android factory reset methods wipe "everything" inside /data/data. This can be frustrating for many, as it implies having to set things up entirely from scratch after flashing new ROM's and/or advanced mods/tweaks. I don't know of anyone who likes doing such a repetitive and tiring task, nor I believe that kind of person even exists. Well, unless they have hardcore OCD. Still, I think even such an individual would be frustrated to death at some point (jokes aside). Speaking of repetition and tiredness, Titanium Backup and alike are slow solutions when compared to adk. Besides app data being already in place, adk uses rsync to backup APK's. If you don't know how powerful rsync is, look that up. Last, but not least, the module ships with a terminal tool (`adk`) to batch restore APK's after factory resets.
- User and updated system apps data is moved to /data/media/adk/.appData -- then bind-mounted to the original locations. This is done in post fs data mode for maximum efficiency. If somehow, an APK is missing on the next boot, then the bind-mounting of its data does not occur. Otherwise, the system would remove that data.
- In late start service mode, APKs's are automatically sync'ed to `$(ls -1d /mnt/media_rw/* | head -n1)/adk/apksBkp` (external storage) if found (or else, to `/data/media/adk/apksBkp`). Thanks to rsync's delta algorithm, only changed parts of APK's are copied. Talk about efficiency...



#### PRE-REQUISITES

- Magisk
- Terminal emulator app



#### SETUP STEPS

- First Time
0. Backup your user and updated system apps data, just in case something goes sideways (RECOMMENDED).
1. Backup your user and updated system apps data, just in case something goes sideways (RECOMMENDED).
2. Install adk from Magisk Manager or TWRP.
3. Reboot.
4. Forget.

- After a Factory Reset
1. Install adk from Magisk Manager or TWRP.
2. Reboot.
3. Locate your favorite backed up terminal app in `[external storage]/adk/apksBkp` or `/data/media/adk/apksBkp` and install it.
4. Run the command `adk`, type `.` (that's a dot), press the enter key and wait. This will automatically reinstall all backed up APKs.
5. Reboot.
6. Forget.



#### DEBUGGING & ADVANCED INFO

- logsDir=/data/media/adk/logs
- Package names of user and UPDATED system apps placed in /data/media/adk/config.txt are ignored (blacklisted). Other system packages placed in the same file are whitelisted. In other words, including system package names in config.txt whitelists them, whereas user and updated system apps are blacklisted. The reasoning behind this is that non-update-able (i.e., through Play Store) system apps are usually incompatible across different ROM's. Thus, their data is left in /data/data. Only user and updated system apps data is moved to the safer location.
- While in recovery and after flashing the module, the command `adk` is available for rolling back all changes and completely uninstalling adk.



#### ONLINE SUPPORT

- [Git Repository](https://github.com/Magisk-Modules-Repo/App-Data-Keeper)
- [XDA Thread](https://forum.xda-developers.com/apps/magisk/magisk-module-app-data-keeper-adk-t3822278)



#### LATEST CHANGES

**2018.8.1 (201808010)**
- Do not run post-fs-data.sh in a background subshell
- Fixed "pm not found" when trying to restore APK's
- General optimizations
- Striped down (removed unnecessary code & files)
- Updated documentation

**2018.7.29 (201807290)**
- Auto-detect whether adk should go to bin or xbin dir to avoid bootloops
- General optimizations
- Updated documentation

**2018.7.28**
- Initial release
