#!/bin/bash
# =============================================================
# Oracle RMAN Backup Script with Auto-Dated Directory
# =============================================================

# --- Konfigurasi dasar environment ---
export ORACLE_SID=orcl
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_HOSTNAME=exaprimary
export PATH=$PATH:$ORACLE_HOME/bin

# --- Buat format tanggal dan direktori backup ---
DATE_DIR=$(date +%Y-%m-%d)
DATETIME=$(date +%d%m%y_%H%M%S)
BACKUP_BASE="/home/oracle/backup/ORCL"
BACKUP_DIR="${BACKUP_BASE}/${DATE_DIR}"
LOG_DIR="/home/oracle/backup/log"

# --- Buat direktori jika belum ada ---
mkdir -p "${BACKUP_DIR}"
mkdir -p "${LOG_DIR}"

# --- Jalankan RMAN Backup ---
${ORACLE_HOME}/bin/rman target=/ log="${LOG_DIR}/alertbackupORCL_${DATETIME}.log" <<EOF
run
{
  crosscheck backup;
  crosscheck archivelog all;
  delete noprompt expired archivelog all;
  delete noprompt expired backup;

  backup as compressed backupset incremental level 0 database
    format '${BACKUP_DIR}/data_level0_%d_%s_%p_%c_%T.bkp';

  backup as compressed backupset incremental level 0 archivelog all
    format '${BACKUP_DIR}/archive_level0_%d_%s_%p_%c_%T.bak';

  backup current controlfile for standby
    format '${BACKUP_DIR}/standby_controlfile_level0_%d_%s_%p_%c_%T.bkp';

  backup current controlfile
    format '${BACKUP_DIR}/current_controlfile_level0_%d_%s_%p_%c_%T.bkp';
}
EXIT;
EOF

