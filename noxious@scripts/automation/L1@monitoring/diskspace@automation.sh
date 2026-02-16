#!/bin/bash

# Konfigurasi Oracle Env
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#-------------------------------
# Monitoring ASM (jika tersedia)
#-------------------------------
echo ""
echo "📦 Monitoring ASM Usage (jika ada)..."
echo ""

ASM_SID=$(ps -ef | grep pmon | grep -i asm | awk -F_ '{print $NF}' | head -1)

if [[ -n "$ASM_SID" ]]; then
  export ORACLE_SID=$ASM_SID
  sqlplus -s / as sysasm <<EOF
SET LINESIZE 200
SET PAGESIZE 100
COL name FORMAT A20
COL type FORMAT A10
COL total_mb FORMAT 999,999
COL free_mb FORMAT 999,999
COL used_pct FORMAT 999.99

SELECT name,
       type,
       total_mb,
       free_mb,
       ROUND((total_mb - free_mb) / total_mb * 100, 2) AS used_pct
FROM v\$asm_diskgroup;
EOF
else
  echo "⚠️  ASM tidak terdeteksi pada server ini."
fi

#-------------------------------
# Monitoring Non-ASM Filesystem
#-------------------------------
echo ""
echo "💾 Monitoring Semua Filesystem (df -h)..."
echo ""
df -hT | column -t

#-------------------------------
# Footer
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

