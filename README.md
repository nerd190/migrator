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

This is a ROM migration utility. On the flip side, it is a full backup solution, thanks to rsync and OpenSSH capabilities. Note: this is in no way associated, nor does it have anything to do with the app "Migrate". While both have similar goals, they work differently and are not developed by the same individual/group.

Regarding backups, these are just a secondary feature - the other side of the coin. You don't need to backup anything before using the data migration (and automatic factory reset) feature. In fact, even if you don't have the module installed, flashing it twice from recovery triggers data migration and factory reset. This is because apps are not copied (this takes time). Instead, they are moved to a location that is not wiped out by a regular factory reset. As you can imagine, this process is completed in seconds.

Next, during the automatic factory reset, select data is left intact. Refer to the `NOTES/TIPS` section below for details.

Finally, upon boot, apps are reinstalled (because recompilation is necessary) and respective data - instantly moved back to /data/data/. Symbolic links and filesystem permissions are handled afterwards.



---
#### PRE-REQUISITES

- Magisk 17.0+
- Terminal emulator



---
#### CONFIG

*Basic*

nobkp -- Disable automatic backups.

bkpFreq=8 -- Incremental backup frequency in hours (value must be an integer, default: 8)

inc <egrep pattern> -- Include packages in migrations and backups. If <package name> is not specified, all user apps are included. e.g., `inc sp.*fy|faceb`

exc <egrep pattern> -- Exclude packages from migrations and backups. e.g., `exc google`

noauto -- Do not migrate/auto-restore apps.

nowipe -- Do not auto-wipe /data and /cache. Note that this also means extra data (e.g., system settings, Magisk modules) won't be preserved.

*Advanced*

delete <paths> -- Remove <paths> after factory reset.

bkp <extra rsync option(s)> <source(s)> <destination> -- Advanced incremental, scheduled backups (rsync -rtu --inplace $bkp_line)

Tip: use $i for internal storage and $e for external media (largest partition) as opposed to writing full paths.

For rsync-specific details, refer to rsync's man page.

*Examples (advanced)*

Full internal storages backup
- bkp --del $i/ $e/full_internal_bkp

Backup a few internal folders to external storage
- bkp --del $i/Download $i/Dukto $e/important_data

Backup data to a remote machine
- bkp -e "ssh -i <path to ssh key>" <source(s)> user@host:/<destination>

Backup backed up apps and respective data to a remote machine
- bkp -e "ssh -i <path to ssh key>" $appBkps $appdataBkps user@host:/<destination>

*Default Configuration*

`inc
nobkp
bkpFreq=8
inc term|provider
migrationThreads=8

#delete /data/data/*provider*

#delete /data/system*/0/ /data/system*/sync/ /data/system*/users/

#delete /data/adb/ /data/misc/adb/ /data/misc/bluedroid/ /data/misc/wifi/ /data/ssh/ /cache/magisk*img`



---
#### NOTES/TIPS

The higher the `migrationThreads` value is, the faster apps+data migration runs (at the cost of higher CPU power and RAM usages). Obviously you should not abuse this.

The word `provider` matches packages that store/provide contacts, SMSs/MMSs, call logs, etc.. Unfortunately, this kind of data is not guaranteed to work across different Android versions or heavily distinct ROMs (e.g., LineageOS - stock).



---
#### TERMINAL

Running `migrator` as root launches a wizard. Included options are incremental backups, data restore, and more.



---
#### SETUP STEPS

- Install
1. Flash the zip from Magisk Manager or custom recovery.
2. Reboot.
3. Customize config.txt (optional).

- Uninstall
1. Use Magisk Manager (app) or Magisk Manager for Recovery Mode (utility).
2. Reboot.
3. Remove /data/media/adk and/or <external storage>/adk (optional).

- Factory reset
1. Reflash the same version from custom recovery to migrate and wipe data.
2. Install new ROM, kernel, Magisk, GApps, etc (optional).
3. Reboot.



---
#### DEBUGGING & ADVANCED INFO

Apps are temporarily disabled during data restore.

$bkpFreq for "bkp <extra rsync option(s)> <source(s)> <destination>" is $((bkpFreq + 3600)). That is, one hour after the set value. This prevents conflicts with bkp_appdata().

If /data/media/adk/config.txt is missing, $modPath/default_config.txt is automatically copied to that location.

If the file /data/.migrator exists during a reflash, migrator reinstalls itself. No data migration/wipe is performed.

Logs are stored at /data/media/adk/logs/.

Migrated data includes adb/, app/ /data/ data/.*provider.*/, misc/(adb/|bluedroid/|vold/|wifi/), ssh/, system.*/(0/accounts.*|storage.xml|sync/accounts.*|users/), data/.*provider.* and /cache/magisk.img.

Verbose can be enabled with `touch /data/media/adk/verbose` and disabled with `rm /data/media/adk/verbose`. Under normal conditions, the file is automatically removed on exit.

When external storage is detected, migrator uses the largest partition for backups. Only the inc'd apps are backed up. After a factory reset, /data/media/adk/backups and/or <external storage>/adk/backups folders are renamed to backups.old. Thus, in case the automatic restore fails, backups won't be overwritten and wizard (option 3) can be used alternatively to restore data. The automatic restore has a fail-safe mechanism -- it runs at most 3 times, as neeeded. Apps usually fail to install due to missing dependencies and/or incompatible Android version. After the 6th failed attempt, `/data/media/adk/failed_restores` is renamed to `failed_restores.old`. If you revert to the original name, you get 3 more restore attempts on the next boot.



---
#### LINKS

- [Donation](https://paypal.me/vr25xda/)
- [Facebook page](https://facebook.com/VR25-at-xda-developers-258150974794782/)
- [Git repository](https://github.com/Magisk-Modules-Repo/adk/)
- [rsync](https://rsync.samba.org/)
- [Telegram channel](https://t.me/vr25_xda/)
- [Telegram group](https://t.me/migrator_magisk/)
- [Telegram profile](https://t.me/vr25xda/)
- [XDA thread](https://forum.xda-developers.com/apps/magisk/magisk-module-app-data-keeper-adk-t3822278/)



---
#### LATEST CHANGES

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

**2019.2.2 (201902020)**
- Added `delete` command for removing select data after a factory reset.
- Automatic backups are disabled by default (`nobkp`).
- Experimental fix for push notifications.
- Fixed wizard option 4: backupd not found.
- System-specific settings are not preserved by default. Refer to `README.md` for details.
- Updated usage instructions, module description and defaut config (user config will be reset).

**2019.2.1 (201902010)**
- Always reinstall on reflash (boot mode only).
- Auto-wipe on reflash (recovery mode only) is enabled by default. `nowipe` disables it.
- Do not start automatic backup/restore until system has fully booted.
- Do not treat updated system apps as user apps.
- General fixes
- Increased SDcard wait timeout to 30 minutes (fail-safe).
- Major optimizations
- More accurate encrypted data detection
- New name: Migrator
- rsync 3.1.3 stable
- Updated building and debugging tools.
- Updated documentation & default config (simplified). Note: user config will be reset.
- Verbose is disabled by default.
