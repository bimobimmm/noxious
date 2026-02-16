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

echo -n "Pilih nomor instance untuk cek blocking: "
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

# Warna ANSI
RED=$(tput setaf 1)
RESET=$(tput sgr0)

while true; do
  clear
  echo "Monitoring Blocking Session - Instance: $ORACLE_SID"
  echo "===================================================="

  # [1] Blocking Session List
  sqlplus -s / as sysdba <<EOF
SET LINESIZE 250
SET PAGESIZE 100
SET FEEDBACK OFF

COL blocker_sid      FOR 9999
COL blocked_sid      FOR 9999
COL blocker_user     FOR A15
COL blocked_user     FOR A15
COL status           FOR A10
COL event            FOR A30
COL wait_time        FOR A10
COL seconds_in_wait  FOR 999999

PROMPT
PROMPT [1] Blocker And Who Blocked:

SELECT s1.sid AS blocker_sid,
       s1.username AS blocker_user,
       s2.sid AS blocked_sid,
       s2.username AS blocked_user,
       s2.status,
       s2.event,
       s2.wait_time,
       s2.seconds_in_wait
FROM v\$session s1
JOIN v\$session s2 ON s1.sid = s2.blocking_session
WHERE s2.blocking_session IS NOT NULL;

EOF

  echo ""
  echo "[2] Information SQL Text Blocked:"
  echo ""

  sqlplus -s / as sysdba <<EOF > /tmp/blocking_sql_output.txt
SET LINESIZE 250
SET PAGESIZE 100
SET FEEDBACK OFF

COL sid          FOR 9999
COL username     FOR A15
COL status       FOR A10
COL sql_id       FOR A13
COL elapsed_secs FOR 999999.99 HEADING "ELAPSED(s)"
COL sql_text     FOR A90 WORD_WRAP

SELECT s.sid,
       s.username,
       s.status,
       s.sql_id,
       ROUND(q.elapsed_time/1000000, 2) AS elapsed_secs,
       SUBSTR(q.sql_text, 1, 90) AS sql_text
FROM v\$session s
JOIN v\$sql q ON s.sql_id = q.sql_id
WHERE s.blocking_session IS NULL
  AND s.sid IN (
    SELECT DISTINCT blocking_session
    FROM v\$session
    WHERE blocking_session IS NOT NULL
  );
EOF

  # Highlight merah untuk blocking SQL
  while IFS= read -r line; do
    if echo "$line" | grep -E -q '^[[:space:]]*[0-9]+[[:space:]]+[A-Z]'; then
      echo -e "${RED}${line}${RESET}"
    else
      echo "$line"
    fi
  done < /tmp/blocking_sql_output.txt
  rm -f /tmp/blocking_sql_output.txt

# [3] Count
  sqlplus -s / as sysdba <<EOF
SET FEEDBACK OFF
SET HEADING ON

PROMPT
PROMPT [3] Jumlah Session yang Terlibat Blocking:

SELECT COUNT(*) AS total_blocking_sessions
FROM v\$session
WHERE blocking_session IS NOT NULL;
EOF

  # Informasi jika tidak terdapat blocking
blocking_count=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF
SET FEEDBACK OFF
SELECT COUNT(*) FROM v\$session WHERE blocking_session IS NOT NULL;
EOF
)

  if [[ "$blocking_count" -eq 0 ]]; then
    echo ""
    echo -e "[INFO] ${RED}Tidak ada session yang sedang terblokir saat ini.${RESET}"
  fi

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

