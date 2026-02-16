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
echo -n "Pilih nomor instance untuk audit: "
read pilih
ORACLE_SID=${SID_LIST[$pilih]}
export ORACLE_SID

if [ -z "$ORACLE_SID" ]; then
  echo "Pilihan tidak valid. Keluar."
  exit 1
fi

#-----------------------
#  Looping Audit View
#-----------------------
while true; do
clear
echo -e "\nAudit untuk Instance: $ORACLE_SID"
echo "========================================="

sqlplus -s / as sysdba <<EOF
SET LINESIZE 200
SET PAGESIZE 100

PROMPT
PROMPT [1] Daftar USER & Tanggal Expired:
COL USERNAME FOR A20
COL ACCOUNT_STATUS FOR A20
COL EXPIRY_DATE FOR A30
SELECT USERNAME, ACCOUNT_STATUS, EXPIRY_DATE
FROM DBA_USERS
ORDER BY EXPIRY_DATE;

PROMPT
PROMPT [2] Privilege user non-default Oracle (oracle_maintained = 'N'):
COL grantee FOR A20
COL privilege FOR A30
COL admin_option FOR A10
SELECT a.grantee, a.privilege, a.admin_option
FROM dba_sys_privs a
JOIN dba_users b ON a.grantee = b.username
WHERE b.oracle_maintained = 'N'
ORDER BY a.grantee;

PROMPT
PROMPT [3] Audit Log Aktivitas (Last 50 Entries):
COL username     FORMAT A20
COL action_name  FORMAT A12
COL obj_name     FORMAT A25
COL timestamp    FORMAT A20
SELECT username, 
       action_name, 
       obj_name, 
       TO_CHAR(timestamp, 'DD-MM-YYYY HH24:MI:SS') AS timestamp
FROM (
  SELECT username,
         DECODE(action, 3, 'SELECT', 6, 'UPDATE', 7, 'DELETE', 2, 'INSERT', action) AS action_name,
         obj_name,
         timestamp
  FROM dba_audit_trail
  WHERE action IN (2, 3, 6, 7)
    AND username IS NOT NULL
  ORDER BY timestamp DESC
)
WHERE ROWNUM <= 50;

PROMPT
PROMPT [4] Informasi Database Role dan Open Mode:
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

