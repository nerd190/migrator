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
Backups survive regular TWRP factory resets. If you want another layer of safety, use rsync to copy these to SDcard or remote location -- e.g., `bkp -a --del $backupsDir /mnt/media*/*/migrator`, `bkp -a --del -e "ssh -i <path to ssh key>" $backupsDir user@host:/<destination>`. Beware however that the destination must be a Linux filesystem (e.g., F2FS, EXT[2-4], Btrfs). Why? Mainly because app data contains symbolic links - which can't be stored in mainstream SDcard filesystems - namely those of the FAT (File Allocation Table) family. A workaround is creating an EXT4 image in the SDcard and saving backups there. Run `su -c /sbin/imgtool create <img> <size>` to create the image (size is interpreted in Megabytes). Mount the image with `su -c /sbin/imgtool mount <img> <mount point>`. Many users may find this complicated. I will automate this process at some point. Meanwhile, using a secondary SDcard partition (with the appropriate filesystem) is much easier.

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

disable <module ID> -- Disable Magisk modules after data migration and factory reset. This supports wildcards. e.g., `disable *xposed*`

exc <egrep pattern> -- Exclude packages from migrations and backups. e.g., `exc pitchblack`, `exc google`

inc <egrep pattern> -- Include packages in migrations and backups. If <package name> is not specified, all user apps are included. e.g., `inc faceb`, `inc sp.*fy|whatsa|dukto`

noapps -- Do not migrate/auto-restore apps.

nobkp -- Disable automatic backups.

nowipe -- Do not auto-wipe /data. Note that this means extra data (e.g., system settings, Magisk modules) won't be preserved.


*Advanced*

bkp <extra rsync option(s)> <source(s)> <destination> -- Advanced incremental, scheduled backups (rsync -rtu --inplace $bkp_line)

For rsync-specific details, refer to rsync's man page.

remove <paths> -- Remove <paths> after factory reset. This can be used to remove virtually anything (including Magisk modules). Its main purpose is excluding problematic data from migration/preservation. This supports wildcards. e.g., `remove $MOUNTPATH/*xposed*`

threads=8 -- The higher the number, the faster apps+data migration runs (at the cost of higher CPU power and RAM usages). Obviously you should not abuse this.

*Examples (advanced)*

Backup backed up apps and respective data to external storage
- bkp -a --del $backupsDir /mnt/media*/*/migrator

Backup data to a remote machine
- bkp -e "ssh -i <path to ssh key>" <source(s)> user@host:/<destination>

Backup backed up apps and respective data to a remote machine
- bkp -a --del -e "ssh -i <path to ssh key>" $backupsDir user@host:/<destination>


*Default Configuration*

`inc
#nobkp
#noapps
#nowipe
threads=8
bkpFreq=8
inc terminal
inc topjohnwu
#exc pitchblack
disable *xposed*
#remove $MOUNTPATH/*xposed*`



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


- Migrate

0. *You may want to backup SMS/MMS messages, contacts and call logs using other means. Currently these are not guaranteed to be migrated fully/successfully.

1. Reflash the same version from custom recovery to migrate data. /data is automatically wiped afterwards. Relevant data remains intact.

2. Disable, remove or update platform dependent Magisk modules before rebooting to the new system! A good example is Xposed Framework. You don't want - for instance, systemless Xposed for Nougat on Oreo and vice versa. After migration, Magisk image is automatically mounted to /M, so that users can disable/remove modules with ease. Recall that you can also use the config constructs `disable <module ID>` or `remove $MOUNTPATH/<module ID>`, as described in the `CONFIG` section above.

3. Format cache, system, etc. - according to your ROM installation instructions. Do NOT wipe /data!

4. Flash ROM, vendor, kernel, Magisk, GApps, etc., and you're done. Recall that Magisk modules don't have to be reinstalled - these are preserved.
Shortly after boot, apps will start popping on the app drawer, one by one.

5. If you are migrating to a lower Android version (e.g., from 8.1 to 7.1.2) or to an entirely different league (e.g. from MIUI to AOSP), you may face issues (such as bootloop or apps force-closing) due to potentially incompatible system data. To prevent this right away, run `sh /data/M` before rebooting. If you already rebooted and the issues are real, go back to recovery and run that command. If even after this, you still face issues, perform a regular factory reset. Migrated apps and respective data survive that. Before the factory reset, you can backup (move) /data/adb/, /data/ssh/, etc. to /data/media/ to preserve Magisk modules, SSH keys and settings, and more. Just remember not to keep any system-specific (problematic) data. If you're not preserving anything, don't forget to Install Magisk and Migrator after the factory reset.

Note: the automatic restore has a fail-safe mechanism -- it runs at most 3 times, as needed. Apps usually fail to install due to missing dependencies and/or incompatible Android version. After the 3rd failed attempt, `/data/media/migrator/failed_restores` is renamed to `failed_restores.old`. If you revert to the original name, you get 3 more restore attempts on the next boot. You can also restore manually at any time with the wizard - `M`. `migrated_data*` and `failed_restores*` folders are refreshed automatically whenever you migrate ROMs. These can be manually removed after migration to save space. You know the restore process is done when `/data/media/migrator/migrated_data/` is gone.



---
#### TERMINAL

- Running `migrator` or `M` as root launches a wizard. Included options are incremental backups, data restore, and more.
- `M -v (or --verbose)` or `touch /data/media/migrator/verbose` enable verbose. To prevent persistent overhead and storage space hijacking, this is valid for a single session only. Verbose is always enabled for automatic restores.



---
#### DEBUGGING & ADVANCED INFO

`$bkpFreq` for `bkp <extra rsync option(s)> <source(s)> <destination>` is `$((bkpFreq + 3600))`. That is, one hour after the set value. This prevents conflicts with bkp_appdata().

Default config is automatically set if `/data/media/migrator/config.txt` is missing.

If the file `/data/.migrator` exists during a reflash, migrator reinstalls itself. No data migration/wipe is performed.

Logs are stored at `/data/media/migrator/logs/`.

Preserved data includes `adb/, app/, misc/(adb/|bluedroid/|vold/|wifi/), ssh/, system.*/([0-99]/accounts.*|storage.xml|sync/accounts.*|users/), user*/*/.*\.provider.* and /data/user*/*/.*\.bookmarkprovider`.



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

**2019.2.12 (201902120)**
- Better compatibility (more data preserved)
- Code and config cleanup
- Fix issues (such as bootloop or apps force-closing) caused by incompatible system data - by running `sh /data/M` in recovery. Refer to README.md for details.
- Fixed <some apps not being backed up or migrated>
- General fixes & optimizations
- Include Magisk Manager in backups and migration (`inc topjohnwu`).
- Updated documentation -- refreshed migration and backup instructions, and more.
- Verbose is always enabled for automatic restores.

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
