#! /usr/bin/bash
ORACLE_HOME=/home/oracle; export ORACLE_HOME
ORACLE_SID=orcl; export ORACLE_SID
LOC_BACKUP='/home/oracle/backup/ORCL/log'; export LOC_BACKUP
DTIME=date '+%Y%m%d_%H%M%S'; export DTIME
LOG=$LOC_BACKUP/arch_del_$DTIME.log; export LOG

$ORACLE_HOME/bin/rman target / nocatalog log=$LOG<<EOF

run {
crosscheck archivelog all;
delete noprompt archivelog until time 'sysdate-1';
}
exit;
EOF
