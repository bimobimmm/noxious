#!/bin/bash

#---------------------
#  Konfigurasi Profile
#---------------------
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#-------------------------------
#  Deteksi semua instance aktif
#-------------------------------
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
#  Input pilihan user
#--------------------
echo -n "Pilih nomor instance untuk monitoring SESSION & SQL: "
read pilih
ORACLE_SID=${SID_LIST[$pilih]}
export ORACLE_SID

if [ -z "$ORACLE_SID" ]; then
  echo "Pilihan tidak valid. Keluar."
  exit 1
fi

#-----------------------
#  Loop Monitoring
#-----------------------
while true; do
  clear
  echo "Monitoring Active Session - Instance: $ORACLE_SID"
  echo "=================================================="
  sqlplus -s / as sysdba <<EOF
SET FEEDBACK OFF
SET LINESIZE 200
SET PAGESIZE 100

PROMPT
PROMPT [1] Total Active Sessions:

SELECT status, COUNT(*) AS jumlah
FROM v\$session
WHERE type='USER'
GROUP BY status;

PROMPT
PROMPT [2] Information User Active:

COL sid         FOR 9999
COL username    FOR A20
COL status      FOR A10
COL logon_time  FOR A20
COL machine     FOR A20
COL program     FOR A25

SELECT sid, username, status,
       TO_CHAR(logon_time, 'DD-MM-YYYY HH24:MI:SS') AS logon_time,
       machine, program
FROM v\$session
WHERE type = 'USER' AND username IS NOT NULL
ORDER BY logon_time;

EOF

echo "#----------------------------"
echo "#"
echo "#TOP SQL QUERY & COMMIT INFO"
echo "#"
echo "#----------------------------"

sqlplus -s / as sysdba <<EOF
SET LINESIZE 300
SET PAGESIZE 100
SET LONG 1000
SET LONGCHUNKSIZE 1000
SET TRIMSPOOL ON
SET WRAP ON
SET FEEDBACK OFF

COL sql_id        FOR A13
COL elapsed       FOR 999,999.000 HEADING "ELAPSED(s)"
COL cpu           FOR 999,999.000 HEADING "CPU(s)"
COL executions    FOR 999,999     HEADING "Execs"
COL sql_text      FOR A90         WORD_WRAP
COL name          FOR A25
COL value         FOR 999,999,999,999
COL sid           FOR 9999
COL username      FOR A15
COL status        FOR A10
COL logon_time    FOR A20
COL sql_id        FOR A13
COL sql_text      FOR A90 WORD_WRAP

PROMPT
PROMPT [3] Top 10 Longest SQL by Elapsed Time:

SELECT * FROM (
  SELECT sql_id,
         elapsed_time/1000000 AS elapsed,
         cpu_time/1000000 AS cpu,
         executions,
         SUBSTR(sql_text, 1, 90) AS sql_text
  FROM v\$sql
  WHERE executions > 0
  ORDER BY elapsed_time DESC
)
WHERE ROWNUM <= 10;

PROMPT
PROMPT [4] Informasi Commit & Rollback:

SELECT name, value
FROM v\$sysstat
WHERE name IN ('user commits', 'user rollbacks');

PROMPT
PROMPT [5] SQL_ID Session ACTIVE:

SELECT s.sid, s.username, s.status, s.sql_id, SUBSTR(q.sql_text, 1, 90) AS sql_text
FROM v\$session s
JOIN v\$sql q ON s.sql_id = q.sql_id
WHERE s.status = 'ACTIVE'
  AND s.username IS NOT NULL
  AND s.type = 'USER'
  AND ROWNUM <= 5;

PROMPT
PROMPT [6] Information Database!:

COL db_name   FOR A15
COL dbid      FOR 9999999999
COL role      FOR A20
COL open_mode FOR A20

SELECT name AS db_name,
       dbid,
       database_role AS role,
       open_mode
FROM v\$database;


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


