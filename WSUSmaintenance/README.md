WSUS Maintenance Scripts
========================

These scripts allow for the maintenance of the WSUS database and processes to prevent sprawl and maintain performance.
These scripts have been tested on WSUS 3.0 on Windows 2012 R2.

With these scripts, and a decent automatic patch plan, you can pretty much set and forget WSUS. This would assume you'd
set auto-approval for Critical and Security updates, and automatically installing patches via GPO.

Files
-----

* __Clean-WSUS.ps1:__ Simple 1 line PS script that removes old data.
* __Sqlbackup.bat:__  Backs up the SQL DB, can set a retention period. Currently written for the local DB using the SQL express client tools.
* __Sync-WSUS.ps1:__ Script that syncs the WSUS server with Microsoft update.
* __Sync-WSUS.xml:__ Export of task from MS Task scheduler, to allow for import elsewhere.
* __WSUSReport.ps1:__ Script to send out an e-mail report or HTML file of WSUS server status.

Usage
-----

* Schedule the powershell scripts and batch script as desired in Microsoft Task scheduler. Some of the scripts produce log files in the working directory.