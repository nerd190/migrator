# Migrator
## Copyright (C) 2018-2019, VR25 @ xda-developers
### License: GPL V3+
#### README.md



---
##### DISCLAIMER

This software is provided as is, in the hope that it will be useful, but without any warranty.
Always read/reread this reference prior to installing/upgrading.
While no cats have been harmed, the author assumes no responsibility for anything that might break due to the use/misuse of it.

A copy of the GNU General Public License, version 3 or newer ships with every build. Please, study it prior to using, modifying and/or sharing any part of this work.

To prevent fraud, DO NOT mirror any link associated with this project; DO NOT share builds (zips) on-line!



---
##### DESCRIPTION

This is a ROM migration utility and a backup solution. It makes switching ROMs easier. It works with hard links (cp -al), rsync, ssh, tar (stub), and gzip/bzip2 (stub). It supports Magisk 17-19.

The default configuration is automatically restored if `/data/media/migrator/config.txt` is missing.

Logs are stored at `/dev/migrator/` (volatile) or `/data/media/migrator/logs/` (persistent).

Preserved data includes APKs, app data, runtime permissions (stub), adb and encryption keys, SMS/MMS, contacts, call logs, media, users and system settings (Bluetooth, ssh, storage, Wi-Fi).



---
##### INCLUDED SOFTWARE

- rsync, copyright (C) 1996-2018, Andrew Tridgell, Wayne Davison, and others



---
##### WARNINGS

Do not try this software cold turkey! Study this documentation and think about edge cases carefully first.

Currently, File-based Encryption (FBE) may not be fully supported, if at all. Devices that use it ask for the password after the lockscreen shows up. This differs from Full Disk Encryption (FDE) in which the password is required to boot. FDE is fully supported. Note that if the recovery (e.g., TWRP) cannot decrypt /data, Migrator will not be able to work in recovery mode.

Complete data migration and restore is NOT guaranteed. Issues are expected due to Android ROM fragmentation. In no particular order, SMS/MMS, contacts, call logs, and users & system settings are more likely to be incompatible across different ROMs. The latter may cause bootloop.



---
##### PRE-REQUISITES

- Magisk 17.0+ (stable releases ONLY)
- Terminal emulator (optional)

Note: all CPU architectures are supported. However, only ARM and x86 rsync binaries are provided. These are used for the more advanced backups only. Most users will not need rsync.



---
##### DEFAULT CONFIG

` `



---
##### GUIDES


- How to Install

1. Flash the zip from Magisk Manager or custom recovery (e.g., TWRP).
2. Reboot.
3. [optional] Customize config.txt.


- How to Uninstall

1. Use Magisk Manager (app) or Magisk Manager for Recovery Mode (utility).
2. Reboot.
3. [Optional] Remove settings - `/data/media/migrator/`.


- How to Migrate ROMs

0. Make sure Migrator is installed.

1. Reflash the same version from custom recovery (e.g., TWRP) to migrate APKs+data.
By default, /data is automatically wiped after migration.
The wipe doesn't affect data such as media, Magisk modules and Wi-Fi settings.
Note: if the file `/data/.migrator` exists, Migrator reinstalls itself. No data migration and wipe are performed.

2. Format cache, system, etc. - according to the ROM installation instructions, but do NOT wipe /data!

4. Flash ROM, vendor, Magisk, kernel, GApps, etc.. Do not reinstall Magisk modules.

Note: migrating to a lower Android version (e.g., from 8.1 to 7.1.2) or to an entirely different league (e.g. from MIUI to AOSP/LineageOS), may cause issues such as bootloop and/or packages force-closing. This is due to potentially incompatible system data. Refer to the terminal section below for a solution.



---
##### TERMINAL

`migrator` or `M` launch the backups/restore wizard.

`M -v` (or --verbose), or `touch /dev/migrator/verbose` enable persistent verbose. This is valid for a single boot session.

[Recovery only] `sh /data/M` launches the /data wipe wizard. It's purpose is simplifying the removal of incompatible system data causing issues after migration. `users and system settings (exc. accounts)` should be targeted first.



---
##### LINKS

- [Donate](https://paypal.me/vr25xda/)
- [Facebook page](https://facebook.com/VR25-at-xda-developers-258150974794782/)
- [Git repository](https://github.com/Magisk-Modules-Repo/migrator/)
- [rsync](https://rsync.samba.org/)
- [Telegram channel](https://t.me/vr25_xda/)
- [Telegram group](https://t.me/migrator_magisk/)
- [Telegram profile](https://t.me/vr25xda/)
- [XDA thread](https://forum.xda-developers.com/apps/magisk/magisk-module-app-data-keeper-adk-t3822278/)



---
##### LATEST CHANGES

- omit /data/unencrypted

- remove app cache from snapshots
- join bkp with backup to get rid of the extra hour timeout
- Custom timeout for FBE and checking for issues
- /data wipe wizard
- Don't backup immediately after boot (~2 hours after)

- Trim app cache
- fix remove and disable commands
- Save apps to sdcard -- cd inDir; tar -c inFile | gzip > outFile -- export backups (tar|tar.gz|tar.bz2)
- Backup and restore migrated data (twrp)
- backup system settings too (especially accounts)
- Support tarball backups
- Real-time verbose
- Runtime perms
- Install apps faster
- Rewritten documentation
- Major optimizations
- Multithread archiving
- individual archives (data only) APKs are already compressed
add versionCode to config.txt to prevent unnecessary overwriting

**2019.2.14 (201902140)**
- General fixes & optimizations
- Workaround for Magisk service.sh bug (script not executed)

**2019.2.12-r3 (201902122)**
- Fixed "refresh_backups not found".
