#!/bin/bash

# -----------------------------
# Konfigurasi Oracle Environment
# -----------------------------
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH
export ORACLE_SID=ORCL  # Ganti dengan SID database primary kamu

# -----------------------------
# Cek Status PMON (Database)
# -----------------------------
pmon_status=$(ps -ef | grep -i [p]mon_$ORACLE_SID)

# -----------------------------
# Fungsi Cek Listener
# -----------------------------
check_listener() {
  lsnrctl status | grep "Listener Log File" > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "✅ Listener sudah aktif."
    return 0
  else
    echo "⚠️  Listener belum aktif."
    return 1
  fi
}

# -----------------------------
# Kondisi Jika PMON Aktif
# -----------------------------
if [[ -n "$pmon_status" ]]; then
  echo "✅ Database dengan SID '$ORACLE_SID' sudah aktif."
  check_listener
  if [[ $? -ne 0 ]]; then
    read -p "❓ Ingin menyalakan Listener? (Y/N): " yn
    case $yn in
      [Yy]* ) 
        echo "🚀 Menyalakan listener..."
        lsnrctl start
        ;;
      * )
        echo "⏹️  Listener tidak dinyalakan."
        ;;
    esac
  fi

else
  # -----------------------------
  # Kondisi Jika PMON Tidak Aktif
  # -----------------------------
  echo "⛔ Database dengan SID '$ORACLE_SID' belum aktif."
  read -p "❓ Ingin menyalakan Database dan Listener? (Y/N): " yn
  case $yn in
    [Yy]* )
      echo "🔓 Membuka database dan listener..."
      sqlplus -s / as sysdba <<EOF
STARTUP;
EXIT;
EOF
      lsnrctl start
      ;;
    * )
      echo "❌ Startup database dan listener dibatalkan."
      ;;
  esac
fi

# -----------------------------
# Kembali ke Menu Utama
# -----------------------------
echo ""
echo "-----------------------------------------------------------------"
echo "Tekan [Q] untuk kembali ke menu utama atau [CTRL+C] untuk keluar."
echo "-----------------------------------------------------------------"
read -t 30 -n 1 key
if [[ "$key" == "q" || "$key" == "Q" ]]; then
  exec /home/oracle/noxious@scripts/automation/L2@action/L2@action.sh
else
  exit 0
fi

