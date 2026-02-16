#!/bin/bash

# Konfigurasi Oracle Env
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#-------------------------------
# Deteksi Instance
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

if [[ -z "$ORACLE_SID" ]]; then
  echo "❌ Pilihan tidak valid. Keluar."
  exit 1
fi

#-------------------------------
# Cari Alert Log
#-------------------------------
alert_log=$(find "$ORACLE_BASE/diag/rdbms" -type f -name "alert_${ORACLE_SID,,}.log" 2>/dev/null | head -1)

if [[ -z "$alert_log" ]]; then
  echo "❌ Alert log untuk $ORACLE_SID tidak ditemukan."
  exit 1
fi

#-------------------------------
# Tampilkan Log dengan less
#-------------------------------
clear
echo ""
echo "📜 Membuka alert log Oracle untuk: $ORACLE_SID"
echo "📄 File: $alert_log"
echo ""
echo "📝 Menampilkan isi alert log menggunakan 'less'."
echo "ℹ️  Tekan [Q] saat selesai membaca untuk kembali ke menu."
echo ""

sleep 2
less +G "$alert_log"

#-------------------------------
# Kembali ke menu
#-------------------------------
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

