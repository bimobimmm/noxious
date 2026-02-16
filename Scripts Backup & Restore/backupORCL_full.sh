#!/bin/bash
# =============================================================
# Oracle RMAN Weekly FULL Backup Script + PFILE
# =============================================================

# --- Environment Oracle ---
export ORACLE_SID=orcl
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_HOSTNAME=exaprimary
export PATH=$PATH:$ORACLE_HOME/bin

# --- Tanggal & direktori backup ---
DATE_DIR=$(date +%Y-%m-%d)
DATETIME=$(date +%d%m%y_%H%M%S)
BACKUP_BASE="/home/oracle/backup/ORCL"
BACKUP_DIR="${BACKUP_BASE}/${DATE_DIR}_FULL"
LOG_DIR="/home/oracle/backup/log"

# --- Buat direktori jika belum ada ---
mkdir -p "${BACKUP_DIR}"
mkdir -p "${LOG_DIR}"

# --- Backup PFILE dari SPFILE (silent mode) ---
PFILE_BACKUP="${BACKUP_DIR}/init${ORACLE_SID}_${DATETIME}.ora"
sqlplus -s / as sysdba <<EOF
create pfile='${PFILE_BACKUP}' from spfile;
exit;
EOF

# --- Jalankan RMAN FULL Backup ---
${ORACLE_HOME}/bin/rman target=/ log="${LOG_DIR}/alertbackupORCL_FULL_${DATETIME}.log" <<EOF
run
{
  crosscheck backup;
  crosscheck archivelog all;
  delete noprompt expired archivelog all;
  delete noprompt expired backup;

  # FULL DATABASE
  backup as compressed backupset full database
    format '${BACKUP_DIR}/data_full_%d_%s_%p_%c_%T.bkp';

  # ARCHIVELOG
  backup as compressed backupset archivelog all
    format '${BACKUP_DIR}/archive_full_%d_%s_%p_%c_%T.bak';

  # CONTROLFILE & STANDBY CONTROLFILE
  backup current controlfile for standby
    format '${BACKUP_DIR}/standby_controlfile_full_%d_%s_%p_%c_%T.bkp';
  backup current controlfile
    format '${BACKUP_DIR}/current_controlfile_full_%d_%s_%p_%c_%T.bkp';
}
EXIT;
EOF

