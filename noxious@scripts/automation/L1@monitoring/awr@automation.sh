#!/bin/bash

#-------------------------------
#  Konfigurasi Oracle
#-------------------------------
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#-------------------------------
#  Deteksi instance Oracle
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
#  Menjalankan awrrpt.sql
#-------------------------------
echo ""
echo "✅ Instance $ORACLE_SID dipilih. Menjalankan awrrpt.sql..."
echo "📌 Input format, Snap ID, dan nama file output di dalam SQL seperti biasa."
echo "📁 Setelah selesai, file akan dipindahkan otomatis ke:"
echo "   /home/oracle/noxious@scripts/automation/toolsinventory/AWR@automation/"
echo ""

# Simpan direktori awal
original_dir=$(pwd)

# Jalankan SQL*Plus
sqlplus / as sysdba @?/rdbms/admin/awrrpt.sql

#-------------------------------
#  Deteksi dan pindahkan file report terbaru
#-------------------------------
echo ""
echo "🔎 Mendeteksi file AWR yang baru dibuat..."

# Temukan file terbaru (html/txt) di direktori sekarang
latest_file=$(ls -t *.html *.txt 2>/dev/null | head -n 1)

if [[ -n "$latest_file" ]]; then
  target_dir="/home/oracle/noxious@scripts/automation/toolsinventory/AWR@automation"
  mkdir -p "$target_dir"
  mv "$latest_file" "$target_dir/"
  echo "✅ File $latest_file telah dipindahkan ke $target_dir/"
else
  echo "⚠️ Tidak ditemukan file .html atau .txt di direktori ini."
fi

# Kembali ke direktori awal (opsional)
cd "$original_dir"

