#!/bin/bash

PASSWORD="123"

#---------------------
#  Konfigurasi Oracle
#---------------------
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#---------------------
#  Menu L2 Tools
#---------------------
while true; do
  clear
  echo "============================================================="
  echo ""
  echo "              WARNING! CAREFULL ON PRODUCTION!"
  echo ""
  echo "           NOXIOUS L2 ORACLE MONITORING TOOL V1.0"
  echo "           author by bimoanggorojatii@gmail.com"
  echo ""
  echo "                                                11, July 2025"
  echo "============================================================="
  echo ""
  echo " [1] Kill Blocking Session (Manual)"
  echo " [2] Cpu usage & Session Memory Usage (PGA & UGA)"
  echo " [3] Grants Users Access"
  echo " [4] Revoke Users Access"
  echo " [5] Startup Database & Listener"
  echo "-------------------------------------------------------------"
  echo ""
  echo " [L1] Kembali ke Menu Monitoring (L1)"
  echo " [Q]  Keluar dari Tools"
  echo ""
  echo "-------------------------------------------------------------"
  read -p "Masukkan pilihan Anda: " pilihan

  case $pilihan in
    1) bash "/home/oracle/noxious@scripts/automation/L2@action/killblocking@tool.sh" ;;
    2) bash "/home/oracle/noxious@scripts/automation/L2@action/cpuusage@tool.sh" ;;
    3) bash "/home/oracle/noxious@scripts/automation/L2@action/grantaccess@tool.sh" ;;
    4) bash "/home/oracle/noxious@scripts/automation/L2@action/revokeaccess@tool.sh" ;;
    5) bash "/home/oracle/noxious@scripts/automation/L2@action/startup@automation.sh";;

[Ll][1])
  echo ""
  echo "🔁 Kembali ke menu utama monitoring L1..."
  sleep 1
  bash /home/oracle/noxious@scripts/automation/L1@monitoring/noxious@monitoring.sh
  exit
  ;;

    [Qq])
      echo ""
      echo "👋 Keluar dari NOXIOUS L2 TOOLS. Sampai jumpa!"
      echo ""
      exit 0
      ;;

    *)
      echo "❌ Pilihan tidak valid. Silakan pilih ulang."
      sleep 2
      ;;
  esac
done

