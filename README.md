# Migrator
## Copyright (C) 2018-2019, VR25 @ xda-developers
### License: GPL V3+
#### README.md



---
#### DISCLAIMER

This software is provided as is, in the hope that it will be useful, but without any warranty. Always read/reread this reference prior to installing/upgrading. While no cats have been harmed, I assume no responsibility under anything which might go wrong due to the use/misuse of it.

A copy of the GNU General Public License, version 3 or newer ships with every build. Please, study it prior to using, modifying and/or sharing any part of this work.

To prevent fraud, DO NOT mirror any link associated with this project; DO NOT share ready-to-flash-builds (zips) on-line!



---
#### INCLUDED SOFTWARE
- rsync, copyright (C) 1996-2018, Andrew Tridgell, Wayne Davison, and others



---
#### DESCRIPTION

This is a ROM migration utility. On the flip side, it is a full backup solution. Note: this is in no way associated, nor does it have anything to do with the app "Migrate". While both have similar goals, they work very differently and are not developed by the same individual/group.

Regarding backups, these are a secondary feature - the other side of the coin. You don't need to backup anything before migrating data. In fact, even if Migrator is not installed, flashing it twice from recovery triggers data migration and automatic factory reset. Migration consists on moving data to a safe location and restoring it shortly after boot. During a factory reset, relevant data that was not moved is kept.

Backups are the snapshot type and super fast - thanks to the magic of hard links. These take virtually no extra space in your internal storage. Yes, you do not need an SDcard. If you find this hard to believe, just google `hard links`.
Moving on - after the first snapshot, there will always be two snapshots at a given time. How different these are depend on the number of hours at which each was taken (`bkpFreq`) - and modifications made to apps and respective data within that time frame.
Backups survive regular TWRP factory resets. If you want another layer of safety, use rsync to copy these to SDcard or remote location. Beware however that the destination must be a Linux filesystem (e.g., F2FS, EXT[2-4], Btrfs). Why? Mainly because app data contains symbolic links - which can't be stored in mainstream SDcard filesystems - namely those of the FAT (File Allocation Table) family.

Once the system has fully booted, apps are reinstalled and respective data - instantly moved back to /data/data/. The final step of each individual app restore implies recreating library symbolic link, setting data ownership and filesystem permissions, and restoring SELinux context. Apps are disabled before data restore and re-enabled afterwards.



---
#### PRE-REQUISITES

- Magisk 17.0+
- Terminal emulator (optional)

Note: all CPU architectures are supported. I only provide ARM and x86 rsync binaries, though. These are used for the more advanced backups. Most users won't need that.



---
#### CONFIG


*Basic*

bkpFreq=8 -- Incremental backup frequency in hours - the value must be an integer (default: 8).

disable <module ID> -- Disable Magisk modules after data migration and factory reset. e.g., `disable xposed`

inc <egrep pattern> -- Include packages in migrations and backups. If <package name> is not specified, all user apps are included. e.g., `inc faceb`, `inc sp.*fy|whatsa|dukto`

exc <egrep pattern> -- Exclude packages from migrations and backups. e.g., `exc pitchblack`, `exc google`

noapps -- Do not migrate/auto-restore apps.

nobkp -- Disable automatic backups.

nowipe -- Do not auto-wipe /data and /cache. Note that this means extra data (e.g., system settings, Magisk modules) won't be preserved.


*Advanced*

remove <paths> -- Remove <paths> after factory reset. This can be used to remove virtually anything (including Magisk modules). Its main purpose is excluding problematic data from migration/preservation. Refer to *Default Configuration* below for examples.

bkp <extra rsync option(s)> <source(s)> <destination> -- Advanced incremental, scheduled backups (rsync -rtu --inplace $bkp_line)

For rsync-specific details, refer to rsync's man page.

*Examples (advanced)*

Backup a few internal folders to external storage
- bkp --del /sdcard/Download /sdcard/Dukto /mnt/media*/*/important_data

Backup data to a remote machine
- bkp -e "ssh -i <path to ssh key>" <source(s)> user@host:/<destination>

Backup backed up apps and respective data to a remote machine
- bkp -e "ssh -i <path to ssh key>" $backupsDir user@host:/<destination>


*Default Configuration*

`inc
#nobkp
#noapps
#nowipe
threads=8
bkpFreq=8
inc terminal
#exc pitchblack

disable xposed

#remove $MOUNTPATH/xposed

#remove /data/user*/*.provider* /data/user*/*.bookmarkprovider

#remove /data/system*/0/ /data/system*/sync/ /data/system*/users/

#remove /data/adb/ /data/misc/adb/ /data/misc/bluedroid/ /data/misc/wifi/ /data/ssh/ /cache/magisk*img`



---
#### SETUP STEPS

- Install
1. Flash the zip in Magisk Manager or custom recovery.
2. Reboot.
3. Customize config.txt (optional).

- Uninstall
1. Use Magisk Manager (app) or Magisk Manager for Recovery Mode (utility).
2. Reboot.
3. Remove `/data/media/migrator` (optional).


- ROM Migration

0. *You may want to backup SMS/MMS messages, contacts and call logs using other means. Currently these are not guaranteed to be migrated fully/successfully.*

1. Reflash the same version from custom recovery to migrate data. /data and /cache are automatically wiped afterwards.

2. Disable, remove or update platform dependent Magisk modules before rebooting to the new system! A good example is Xposed Framework. You don't want - for instance, systemless Xposed for Nougat on Oreo and vice versa. After migration, Magisk image is automatically mounted to /M, so that users can disable/remove modules with ease. Recall that, you can also use the config constructs `disable <module ID>` or `remove $MOUNTPATH/<module ID>`, as described in the `CONFIG` section above.

3. *Reboot recovery*.

4. Install new ROM, kernel, Magisk, GApps, etc., and you're done. Again, you must flash Magisk, not Magisk modules - these are preserved. Shortly after boot, apps will start popping on the app drawer, one by one.



---
#### NOTES/TIPS

`/data/user*/*.provider* /data/user*/*.bookmarkprovider` match content providers' data (e.g., contacts, SMS/MMS messages, call logs). Unfortunately, this kind of data is not guaranteed to work across different Android versions or heavily distinct ROMs (e.g., LineageOS - stock). If you face issues such as constantly crashing Phone, Contacts, Messaging or similar app - run `su -c rm -rf /data/user*/*.provider* /data/user*/*.bookmarkprovider`. Reboot if the problem persists.

The automatic restore has a fail-safe mechanism -- it runs at most 3 times, as needed. Apps usually fail to install due to missing dependencies and/or incompatible Android version. After the 3rd failed attempt, `/data/media/migrator/failed_restores` is renamed to `failed_restores.old`. If you revert to the original name, you get 3 more restore attempts on the next boot. You can also restore manually at any time - `su -c M`.

The higher the number of `threads` is, the faster apps+data migration runs (at the cost of higher CPU power and RAM usages). Obviously you should not abuse this.



---
#### TERMINAL

- Running `migrator` or `M` as root launches a wizard. Included options are incremental backups, data restore, and more.
- `M -v (or --verbose)` or `touch /data/media/migrator/verbose` enable verbose. To prevent persistent overhead and storage space hijacking, this is valid for a single session only.



---
#### DEBUGGING & ADVANCED INFO

`$bkpFreq` for `bkp <extra rsync option(s)> <source(s)> <destination>` is `$((bkpFreq + 3600))`. That is, one hour after the set value. This prevents conflicts with bkp_appdata().

If `/data/media/migrator/config.txt` is missing, `$modPath/default_config.txt` is automatically copied to that location on the next launch.

If the file `/data/.migrator` exists during a reflash, migrator reinstalls itself. No data migration/wipe is performed.

Logs are stored at `/data/media/migrator/logs/`.

Migrated data includes `adb/, app/, /data/user*/*/.*provider.*/, misc/(adb/|bluedroid/|vold/|wifi/), ssh/, system.*/([0-99]/accounts.*|storage.xml|sync/accounts.*|users/), data/.*provider.* and /cache/magisk.img`.



---
#### LINKS

- [Donation](https://paypal.me/vr25xda/)
- [Facebook page](https://facebook.com/VR25-at-xda-developers-258150974794782/)
- [Git repository](https://github.com/Magisk-Modules-Repo/migrator/)
- [rsync](https://rsync.samba.org/)
- [Telegram channel](https://t.me/vr25_xda/)
- [Telegram group](https://t.me/migrator_magisk/)
- [Telegram profile](https://t.me/vr25xda/)
- [XDA thread](https://forum.xda-developers.com/apps/magisk/magisk-module-app-data-keeper-adk-t3822278/)



---
#### LATEST CHANGES

**2019.2.8 (201902080)**
- All CPU architectures are now supported. I only provide ARM and x86 rsync binaries, though. Only the more advanced backups need rsync.
- Auto-backup config before upgrades. Also, try patching it instead of overwriting.
- Backups and migrated data have the same format. The wizard is able to restore both.
- After migration, mount Magisk image to /M, so that users can remove/disable platform dependent Magisk modules (e.g., systemless Xposed) with ease. These cause bootloop and/or others annoyances. Alternatively, one can use the the config construct `disable <module ID>` or `remove $MOUNTPATH/<module ID>`.
- Major fixes & optimizations
- Migrate multiuser data as well. Apps are not included.
- Module ID changed to `migrator`. Legacy version (adk) is removed automatically.
- Preserve all traces of standard content providers' data (e.g., contacts, call logs, SMS/MMS messages).
- Super fast snapshots with virtually no extra storage space needed (no sdcard, no problem). Automatic backups are enabled by default.
- Updated documentation (much more detailed and comprehensive) and default config (user config will be reset this time).
- Wizard can be launched either by running `migrator` or `M`. `M -v (or --verbose)` enables verbose for the next running session. The 5th option from the wizard menu shows the project's documentation.

**2019.2.3.1 (201902031)**
- Fixed app data backup logic error.
- Wizard option 7 can also remove backups of excluded apps.

**2019.2.3 (201902030)**
- Added [Telegram group link](https://t.me/migrator_magisk/).
- Customizable multithreading for apps+data migration.
- Do not retry app restore after the 3rd failed attempt. This can be overridden. Refer to README.md for details.
- General fixes & optimizations
- Reverted "do not preserve system settings by default" (false alarm).
- Show package names during apps+data migration.
- Updated documentation and config.
- Wait until pm (package manager) is ready before initiating app restore.
