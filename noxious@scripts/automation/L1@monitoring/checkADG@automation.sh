#!/bin/bash

#---------------------
#
#  Konfigurasi Profile
#
#---------------------

ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#---------------------------------------------
#
#  Deteksi semua instance yang sedang running
#
#---------------------------------------------

echo "Mendeteksi instance Oracle yang sedang aktif..."
ps -ef | grep pmon | grep -v grep | awk -F_ '{print $NF}' > /tmp/instance_list.txt

echo "Daftar Instance Terdeteksi:"
i=1
declare -A SID_LIST
while read line; do
  echo "$i. $line"
  SID_LIST[$i]=$line
  ((i++))
done < /tmp/instance_list.txt

#--------------------
#
#  Input pilihan user
#
#--------------------

echo -n "Pilih nomor instance yang ingin dimonitor: "
read pilih
ORACLE_SID=${SID_LIST[$pilih]}
export ORACLE_SID

if [ -z "$ORACLE_SID" ]; then
  echo "Pilihan tidak valid. Keluar."
  exit 1
fi

echo -e "\nMonitoring Replikasi Data Guard untuk instance: $ORACLE_SID"
echo "=============================================================="

#-----------------------
#
# Loop Monitoring
#
#-----------------------

while true; do
  clear
  echo "Timestamp: $(date '+%d-%m-%Y %H:%M:%S')"
  echo "=============================================================="

  sqlplus -s / as sysdba <<EOF
  SET LINESIZE 200
  SET PAGESIZE 100
  COL name FOR a15
  COL database_role FOR a20
  COL open_mode FOR a20

  PROMPT
  PROMPT [1] ALERT dari v\$dataguard_status (status terakhir):
  SET PAGESIZE 9999
  SET LINESIZE 200
  ALTER SESSION SET nls_date_format='dd-mm-yyyy hh24:mi:ss';
  SELECT message FROM v\$dataguard_status;

  PROMPT
  PROMPT [2] Status DEST_ID dan Error:
  COLUMN error FORMAT a55
  SELECT dest_id, status, error FROM v\$archive_dest;

  PROMPT
  PROMPT [3] Status MRP (Managed Recovery Process):
  SELECT process, status, thread#, sequence# FROM v\$managed_standby WHERE process LIKE 'MRP%';

  PROMPT
  PROMPT [4] Applied Sequences Terakhir (5 hari terakhir):
  SELECT * FROM (
      SELECT thread#, max(sequence#) AS seq, APPLIED
      FROM v\$archived_log
      WHERE first_time >= sysdate - 5
      GROUP BY thread#, first_time, sequence#, APPLIED
      ORDER BY first_time DESC
  ) WHERE rownum <= 10 AND APPLIED = 'YES';

  PROMPT
  PROMPT [5] Cek FRA Usage:
  SET LINESIZE 500
  COL NAME FOR a50
  SELECT name,
         ROUND(SPACE_LIMIT/1024/1024/1024,2) AS "allocated space gb",
         ROUND(SPACE_USED/1024/1024/1024,2) AS "used space gb",
         ROUND(SPACE_RECLAIMABLE/1024/1024/1024,2) AS "space reclaim gb",
         (SELECT ROUND(ESTIMATED_FLASHBACK_SIZE/1024/1024/1024,2)
          FROM v\$FLASHBACK_DATABASE_LOG) AS "estimated space gb"
  FROM v\$recovery_file_dest;

  PROMPT
  PROMPT [6] Check GAP Sequence Detail:
  ALTER SESSION SET nls_date_format='DD-MM-YYYY HH24:MI:SS';
  SELECT A.THREAD#, B.LAST_SEQ, A.APPLIED_SEQ, A.LAST_APP_TIMESTAMP,
         B.LAST_SEQ - A.APPLIED_SEQ AS ARC_DIFF
  FROM (
      SELECT THREAD#, MAX(SEQUENCE#) APPLIED_SEQ, MAX(NEXT_TIME) LAST_APP_TIMESTAMP
      FROM GV\$ARCHIVED_LOG
      WHERE APPLIED = 'YES' OR APPLIED = 'IN-MEMORY'
      GROUP BY THREAD#
  ) A,
  (
      SELECT THREAD#, MAX(SEQUENCE#) LAST_SEQ
      FROM GV\$ARCHIVED_LOG
      GROUP BY THREAD#
  ) B
  WHERE A.THREAD# = B.THREAD#;

  PROMPT
  PROMPT [7] Informasi Database Role dan Open Mode:
  SELECT name, database_role, open_mode FROM v\$database;

EOF

echo ""
  echo "TIME MONITORING -> $(date '+%d-%m-%Y %H:%M:%S')"
  echo ""
  echo "Tekan [Q] untuk kembali ke menu utama atau [CTRL+C] untuk keluar."
  echo ""
  echo "#----------------------------------------"
  echo "#"
  echo "#   SCRIPTS BY NOXIOUS@ROOTS"
  echo "#   AUTHOR BY bimoanggorojatii@gmail.com"
  echo "#"
  echo "#----------------------------------------"

  read -t 30 -n 1 key
  if [[ "$key" == "q" || "$key" == "Q" ]]; then
    echo ""
    echo "Kembali ke menu utama..."
    break
  fi

  sleep 30
done

