#!/bin/bash

#---------------------
#  Konfigurasi Profile
#---------------------
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

while true; do
  clear
  echo "Mendeteksi instance Oracle yang sedang aktif..."
  ps -ef | grep pmon | grep -v grep | awk '{print $NF}' | cut -d_ -f3 | nl

  read -p "Pilih nomor instance untuk monitoring switchover: " inst_num
  ORACLE_SID=$(ps -ef | grep pmon | grep -v grep | awk '{print $NF}' | cut -d_ -f3 | sed -n "${inst_num}p")

  if [ -z "$ORACLE_SID" ]; then
    echo "Instance tidak ditemukan. Kembali ke menu utama..."
    sleep 2
    break
  fi

  export ORACLE_SID=$ORACLE_SID
  export ORAENV_ASK=NO
  . oraenv >/dev/null

  NOW=$(date '+%d-%m-%Y %H:%M:%S')
  echo ""
  echo "Monitoring Switchover Status - Instance: $ORACLE_SID"
  echo "=============================================================="
  echo "Tanggal/Waktu: $NOW"
  echo "=============================================================="

  sqlplus -s / as sysdba <<EOF
SET LINESIZE 250
SET PAGESIZE 100
SET FEEDBACK OFF
COL STATUS            FORMAT A10
COL ERROR             FORMAT A60
COL NAME              FORMAT A25
COL VALUE             FORMAT A50
COL MESSAGE           FORMAT A120
COL DATABASE_ROLE     FORMAT A20
COL OPEN_MODE         FORMAT A15
COL PROTECTION_MODE   FORMAT A20
COL SWITCHOVER_STATUS FORMAT A20
COL PROCESS           FORMAT A10
COL LAST_APP_TIMESTAMP FORMAT A20
COL ARC_DIFF          FORMAT 9999
COL TIME_COMPUTED     FORMAT A20
COL LOG_MODE          FORMAT A15
COL FORCE_LOGGING     FORMAT A15

PROMPT
PROMPT [1] DEST_ID STATUS
SELECT DEST_ID, STATUS, ERROR FROM V\$ARCHIVE_DEST_STATUS ORDER BY DEST_ID;

PROMPT
PROMPT [2] ARCHIVE LOG MODE + FORCE LOGGING
SELECT LOG_MODE, FORCE_LOGGING FROM V\$DATABASE;

PROMPT
PROMPT [3] STANDBY FILE MANAGEMENT
SELECT NAME, VALUE FROM V\$PARAMETER WHERE NAME = 'standby_file_management';

PROMPT
PROMPT [4] ARCHIVE LOG GAP (v\$dataguard_status.message)
SELECT MESSAGE FROM V\$DATAGUARD_STATUS WHERE ROWNUM <= 10;

PROMPT
PROMPT [5] DATABASE ROLE, OPEN MODE, PROTECTION MODE
SELECT DATABASE_ROLE, OPEN_MODE, PROTECTION_MODE FROM V\$DATABASE;

PROMPT
PROMPT [6] SWITCHOVER STATUS
SELECT DATABASE_ROLE, SWITCHOVER_STATUS FROM V\$DATABASE;

PROMPT
PROMPT [7] TRANSPORT LAG
SELECT NAME, VALUE, TIME_COMPUTED FROM V\$DATAGUARD_STATS WHERE NAME = 'transport lag';

PROMPT
PROMPT [8] LAST RECEIVED LOG
SELECT MAX(SEQUENCE#) AS LAST_RECEIVED FROM V\$ARCHIVED_LOG WHERE DEST_ID=1;

PROMPT
PROMPT [9] REDO APPLY STATUS
SELECT PROCESS, STATUS, THREAD#, SEQUENCE# 
FROM V\$MANAGED_STANDBY 
WHERE PROCESS LIKE 'MRP%';

PROMPT
PROMPT [10] LAST APPLIED LOG + TIME + GAP
SELECT 
    THREAD#,
    MAX(SEQUENCE#) AS LAST_SEQ,
    MAX(APPLIED_SEQ#) AS APPLIED_SEQ,
    TO_CHAR(MAX(COMPLETION_TIME), 'DD-MM-YYYY HH24:MI:SS') AS LAST_APP_TIMESTAMP,
    MAX(SEQUENCE#) - MAX(APPLIED_SEQ#) AS ARC_DIFF
FROM (
    SELECT THREAD#, SEQUENCE#, 0 AS APPLIED_SEQ#, FIRST_TIME AS COMPLETION_TIME
    FROM V\$ARCHIVED_LOG WHERE APPLIED='NO'
    UNION ALL
    SELECT THREAD#, SEQUENCE# AS SEQUENCE#, SEQUENCE# AS APPLIED_SEQ#, COMPLETION_TIME
    FROM V\$ARCHIVED_LOG WHERE APPLIED='YES'
)
GROUP BY THREAD#;

PROMPT
PROMPT NOTE:
PROMPT - Switchover hanya bisa dilakukan jika semua kondisi berikut terpenuhi:
PROMPT   1. SWITCHOVER_STATUS = TO STANDBY / TO PRIMARY
PROMPT   2. Tidak ada GAP atau LAG = NULL atau 0
PROMPT   3. REDO APPLY aktif di Standby (MRP0 aktif)

EXIT
EOF

  echo ""
  echo "TIME MONITORING -> $NOW"
  echo ""
  echo "#----------------------------------------"
  echo "#   SCRIPTS BY NOXIOUS@ROOTS"
  echo "#   AUTHOR BY bimoanggorojatii@gmail.com"
  echo "#----------------------------------------"

  echo ""
  read -n1 -r -p "Tekan [Q] untuk kembali ke menu utama, atau [Ctrl+C] untuk keluar: " key
  if [[ "$key" == "q" || "$key" == "Q" ]]; then
    break
  fi
done

