#!/bin/bash

#---------------------
#  Konfigurasi Oracle
#---------------------
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#---------------------
#  Menu Utama
#---------------------
while true; do
  clear
  echo "============================================================="
  echo ""
  echo ""
  echo "           NOXIOUS L1 ORACLE MONITORING TOOL V1.0"
  echo "           author by bimoanggorojatii@gmail.com"
  echo ""
  echo "                                                11, July 2025"
  echo "============================================================="
  echo ""
  echo " [1] Audit User, Privilege & Aktivitas"
  echo " [2] Monitoring Data Guard (ADG)"
  echo " [3] Monitoring Blocking Session"
  echo " [4] Monitoring Session Aktif & TOP SQL_ID"
  echo " [5] Monitoring Tablespace"
  echo " [6] Generate AWR Report"
  echo " [7] Generate ADDM Report"
  echo " [8] Cek Backup RMAN (SQL)"
  echo " [9] Monitoring Diskspace (ASM & Non-ASM)"
  echo "[10] Lihat Alert Log Oracle (Real-time)"
  echo "[11] Switchover Status"
  echo ""  
  echo "" 
  echo "[00] Error ORA Inventory"
  echo ""
  echo " [Q] Keluar"
  echo ""
  echo "-------------------------------------------------------------"
  read -p "Masukkan pilihan Anda: " pilihan

  case $pilihan in
    1)  bash /home/oracle/noxious@scripts/automation/L1@monitoring/audit@automation.sh ;;
    2)  bash /home/oracle/noxious@scripts/automation/L1@monitoring/checkADG@automation.sh ;;
    3)  bash /home/oracle/noxious@scripts/automation/L1@monitoring/checkblocking@automation.sh ;;
    4)  bash /home/oracle/noxious@scripts/automation/L1@monitoring/session@automation.sh ;;
    5)  bash /home/oracle/noxious@scripts/automation/L1@monitoring/tablespace@monitoring.sh ;;
    6)  bash /home/oracle/noxious@scripts/automation/L1@monitoring/awr@automation.sh ;;
    7)  bash /home/oracle/noxious@scripts/automation/L1@monitoring/addm@automation.sh ;;
    8)  bash /home/oracle/noxious@scripts/automation/L1@monitoring/checkbackup@automation.sh ;;
    9)  bash /home/oracle/noxious@scripts/automation/L1@monitoring/diskspace@automation.sh ;;
    10) bash /home/oracle/noxious@scripts/automation/L1@monitoring/alertlog@automation.sh ;;
    11) bash /home/oracle/noxious@scripts/automation/L1@monitoring/switchover@status.sh ;;
    00) bash /home/oracle/noxious@scripts/automation/L1@monitoring/lookup@ORAerror.sh ;;
    [Qq])
      echo ""
      echo "Keluar dari NOXIOUS L1 ORACLE MONITORING TOOL V1.0"
      echo ""
      exit 0
      ;;
    *)
      echo "❌ Pilihan tidak valid. Silakan pilih ulang."
      sleep 2
      ;;
  esac
done

