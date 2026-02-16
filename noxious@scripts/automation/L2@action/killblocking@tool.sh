#!/bin/bash

#---------------------
#  Konfigurasi Oracle
#---------------------
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

LOG_DIR="/home/oracle/noxious@scripts/automation/toolsinventory/BLOCKING@killlog"
LOG_FILE="$LOG_DIR/killblocking_$(date '+%Y%m%d').log"
mkdir -p "$LOG_DIR"

#---------------------
#  Pilih Instance
#---------------------
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

read -p "Pilih nomor instance: " pilih
ORACLE_SID=${SID_LIST[$pilih]}
export ORACLE_SID

if [[ -z "$ORACLE_SID" ]]; then
  echo "❌ Pilihan tidak valid."
  echo ""
  echo "Tekan [Q] untuk kembali ke menu utama atau [CTRL+C] untuk keluar."
  read -t 30 -n 1 key
  if [[ "$key" == "q" || "$key" == "Q" ]]; then
    exec /home/oracle/noxious@scripts/automation/L2@action/L2@action.sh
  else
    exit 0
  fi
fi

#---------------------
#  Info DB
#---------------------
echo ""
echo "🧾 Informasi Database:"
sqlplus -s / as sysdba <<EOF
SET LINESIZE 150
SET PAGESIZE 50
COLUMN name FORMAT A15 HEADING "NAME"
COLUMN database_role FORMAT A20 HEADING "DATABASE_ROLE"
COLUMN open_mode FORMAT A25 HEADING "OPEN_MODE"

SELECT name, database_role, open_mode FROM v\$database;
EOF

#---------------------
#  Tampilkan Blocking Session
#---------------------
echo ""
echo "📦 Menampilkan session yang sedang blocking..."
sqlplus -s / as sysdba <<EOF > /tmp/blocking_session_raw.txt
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SELECT s.sid || ',' || s.serial# || '|' || s.username || '|' || s.machine || '|' || s.program || '|' || s.status || '|' || s.event
FROM v\$session s
JOIN v\$lock l ON s.sid = l.sid
WHERE l.block = 1;
EOF

if [[ ! -s /tmp/blocking_session_raw.txt ]]; then
  echo "✅ Tidak ada session blocking saat ini."
  echo ""
  echo "🕓 Proses selesai pada: $(date '+%d-%m-%Y %H:%M:%S')"
  echo ""
  echo "Tekan [Q] untuk kembali ke menu utama atau [CTRL+C] untuk keluar."
  read -t 30 -n 1 key
  if [[ "$key" == "q" || "$key" == "Q" ]]; then
    exec /home/oracle/noxious@scripts/automation/L2@action/L2@action.sh
  else
    exit 0
  fi
fi

echo -e "SID,SERIAL\tUSERNAME\tMACHINE\t\tPROGRAM\t\t\tSTATUS\t\tEVENT"
while IFS="|" read -r sidserial username machine program status event; do
  color_reset="\e[0m"
  case "$status" in
    ACTIVE)  color="\e[32m" ;;   # Hijau
    INACTIVE) color="\e[31m" ;;  # Merah
    KILLED)  color="\e[90m" ;;   # Abu-abu
    *)       color="\e[33m" ;;   # Kuning
  esac
  echo -e "${color}${sidserial}\t${username}\t${machine}\t${program}\t${status}\t${event}${color_reset}"
done < /tmp/blocking_session_raw.txt

#---------------------
#  Eksekusi Kill
#---------------------
echo ""
read -p "Masukkan SID: " KILL_SID
read -p "Masukkan SERIAL#: " KILL_SERIAL

if [[ -z "$KILL_SID" || -z "$KILL_SERIAL" ]]; then
  echo "❌ SID dan SERIAL# wajib diisi."
  echo ""
  echo "Tekan [Q] untuk kembali ke menu utama atau [CTRL+C] untuk keluar."
  read -t 30 -n 1 key
  if [[ "$key" == "q" || "$key" == "Q" ]]; then
    exec /home/oracle/noxious@scripts/automation/L2@action/L2@action.sh
  else
    exit 0
  fi
fi

read -p "⚠️  Konfirmasi KILL SESSION $KILL_SID,$KILL_SERIAL ? [y/N]: " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  echo "Menjalankan ALTER SYSTEM KILL SESSION..."
  sqlplus -s / as sysdba <<EOF >> "$LOG_FILE"
ALTER SYSTEM KILL SESSION '$KILL_SID,$KILL_SERIAL' IMMEDIATE;
EOF

  echo "$(date '+%d-%m-%Y %H:%M:%S') | KILL SESSION '$KILL_SID,$KILL_SERIAL' | Instance: $ORACLE_SID" >> "$LOG_FILE"

  STATUS_RESULT=$(sqlplus -s / as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT status FROM v\\$session WHERE sid = $KILL_SID AND serial# = $KILL_SERIAL;
EOF
)

  if [[ -z "$STATUS_RESULT" ]]; then
    echo -e "\e[32m🟢 Session $KILL_SID,$KILL_SERIAL sudah tidak ditemukan. Berhasil dikill.\e[0m"
    echo "$(date '+%d-%m-%Y %H:%M:%S') | Status: SUKSES" >> "$LOG_FILE"
  else
    echo -e "\e[31m🔴 Session masih terdeteksi dengan status: $STATUS_RESULT\e[0m"
    echo "$(date '+%d-%m-%Y %H:%M:%S') | Status: MASIH AKTIF ($STATUS_RESULT)" >> "$LOG_FILE"
  fi
else
  echo "❌ Operasi dibatalkan."
