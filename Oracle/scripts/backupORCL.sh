#!/bin/bash
export DATETIME=$(date +%d%m%y_%H%M%S)
export ORACLE_SID=orcl
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1/ORCL
export ORACLE_HOSTNAME=exaprimary
export PATH=$PATH:$ORACLE_HOME/bin

${ORACLE_HOME}/bin/rman target=/ log=/home/oracle/backup/BCKUP/log/alertbackupORCL_${BCKDate}.log  << EOF
run
{
crosscheck backup;
crosscheck archivelog all;
delete noprompt expired archivelog all;
delete noprompt expired backup;
backup as compressed backupset incremental level 0 database format '/home/oracle/backup/BCKUP/Backup_Feb/data_level0_%d_%s_%p_%c_%T.bkp';
backup as compressed backupset incremental level 0 archivelog all format '/home/oracle/backup/BCKUP/Backup_Feb/archive_level0_%d_%s_%p_%c_%T.bak';
backup current controlfile for standby format '/home/oracle/backup/BCKUP/Backup_Feb/exa_controlfile_level0_%d_%s_%p_%c_%T.bkp';
backup current controlfile format '/home/oracle/backup/BCKUP/Backup_Feb/current_controlfile_level0_%d_%s_%p_%c_%T.bkp';
}
EXIT;
EOF

