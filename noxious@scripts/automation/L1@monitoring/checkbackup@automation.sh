#!/bin/bash

#-------------------------------
# Konfigurasi Oracle Environment
#-------------------------------
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#-------------------------------
# Deteksi Instance Aktif
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

echo -n "Pilih nomor instance: "
read pilih
ORACLE_SID=${SID_LIST[$pilih]}
export ORACLE_SID

if [ -z "$ORACLE_SID" ]; then
  echo "❌ Pilihan tidak valid. Keluar."
  exit 1
fi

#-------------------------------
# Jalankan SQL dan tangkap output bersih (CSV-like)
#-------------------------------
sqlplus -s / as sysdba <<EOF > /tmp/rman_backup_report.txt
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 1000
SET TRIMSPOOL ON
SET TERMOUT OFF

SELECT SESSION_KEY || '|' ||
       INPUT_TYPE || '|' ||
       STATUS || '|' ||
       TO_CHAR(START_TIME, 'YYYY-MM-DD HH24:MI:SS') || '|' ||
       TO_CHAR(END_TIME, 'YYYY-MM-DD HH24:MI:SS') || '|' ||
       ROUND(ELAPSED_SECONDS / 3600, 2)
FROM   V\$RMAN_BACKUP_JOB_DETAILS
ORDER  BY SESSION_KEY DESC;
EOF

#-------------------------------
# Tampilkan Header + Output Warna Rapih
#-------------------------------
echo ""
echo "📋 Backup Status RMAN - Instance: $ORACLE_SID"
echo "🕓 $(date '+%d-%m-%Y %H:%M:%S')"
echo ""
printf "%-12s | %-12s | %-25s | %-20s | %-20s | %-7s\n" "SESSION_KEY" "INPUT_TYPE" "STATUS" "START_TIME" "END_TIME" "HOURS"
printf "%s\n" "------------------------------------------------------------------------------------------------------------------------------"

while IFS="|" read -r session input status start_time end_time hours; do
  status_clean=$(echo "$status" | xargs)
  case "$status_clean" in
    "COMPLETED") color="\033[1;32m" ;;         # green
    "FAILED") color="\033[1;31m" ;;            # red
    "COMPLETED WITH WARNINGS") color="\033[1;33m" ;;  # yellow
    *) color="\033[0m" ;;                      # default
  esac

  printf "${color}%-12s | %-12s | %-25s | %-20s | %-20s | %-7s\033[0m\n" \
    "$session" "$input" "$status_clean" "$start_time" "$end_time" "$hours"
done < /tmp/rman_backup_report.txt

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
  sleep 1
  exec /home/oracle/noxious@scripts/automation/L1@monitoring/noxious@monitoring.sh
fi

