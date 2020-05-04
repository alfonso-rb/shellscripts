sqlcmd -S WSUSSERVER -E -Q "EXEC sp_BackupDatabases @backupLocation='D:\MSSQL\Backup\', @backupType='F'"

forfiles /P "D:\MSSQL\Backup" /S /M *.* /D -30 /C "cmd /c del @path"