#!/bin/bash
export DATETIME=$(date +%d%m%y_%H%M%S)
export ORACLE_SID=orcl
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/home/oracle
export ORACLE_HOSTNAME=ol7-19.localdomain
export PATH=$PATH:$ORACLE_HOME/bin

${ORACLE_HOME}/bin/rman target=/ log=/home/oracle/backup/log/alertrestoreORCL_${BCKDate}.log  << EOF

run {
SET NEWNAME FOR DATABASE TO '/home/oracle/backup/Data_file/%b';
SET NEWNAME FOR tempfile 1 TO '/home/oracle/backup/Data_file/%b';
restore database;
switch datafile all;
switch tempfile all;
}
EOF

