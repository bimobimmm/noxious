#!/bin/bash
# ===============================================
# Final V2 Switchover Oracle Data Guard Automation
# Author: Bimo Anggoro Jati
# Date  : 2025-10-04
# ===============================================

# ================= CONFIGURATION =================
PRIMARY_TNS="orcl_primary"
STANDBY_TNS="orcl_standby"
PRIMARY_HOST="192.168.56.11"
STANDBY_HOST="192.168.56.21"
ORACLE_HOME="/u01/app/oracle/product/19.0.0/dbhome_1"
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_HOME PATH

LOG_FILE="/home/oracle/logs/switchover/switchover_$(date +%Y%m%d_%H%M%S).log"
mkdir -p $(dirname $LOG_FILE)

echo "=======================================" | tee -a $LOG_FILE
echo "   ORACLE DATA GUARD SWITCHOVER TOOL   " | tee -a $LOG_FILE
echo "=======================================" | tee -a $LOG_FILE

# ================= FUNCTION ====================
check_arc_diff() {
    sqlplus -S / as sysdba <<EOF
SET LINESIZE 200
COLUMN thread# FORMAT 999
COLUMN last_seq FORMAT 999999
COLUMN applied_seq FORMAT 999999
COLUMN last_app_timestamp FORMAT A20
COLUMN arc_diff FORMAT 999999

SELECT a.thread#, b.last_seq, a.applied_seq, a.last_app_timestamp, b.last_seq - a.applied_seq ARC_DIFF
FROM (
  SELECT thread#, MAX(sequence#) applied_seq, MAX(next_time) last_app_timestamp
  FROM gv\$archived_log
  WHERE applied = 'YES' OR applied='IN-MEMORY'
  GROUP BY thread#
) a,
(
  SELECT thread#, MAX(sequence#) last_seq
  FROM gv\$archived_log
  GROUP BY thread#
) b
WHERE a.thread# = b.thread#;
EOF
}

# ================= STEP 1: CHECK ARC_DIFF =================
echo "[1] Mengecek ARC_DIFF..." | tee -a $LOG_FILE
while true; do
    ARC_DIFF=$(check_arc_diff | awk '/^[0-9]+/ {sum += $5} END {print sum}')
    ARC_DIFF=${ARC_DIFF:-0}  # default 0 jika kosong
    echo "Total ARC_DIFF: $ARC_DIFF" | tee -a $LOG_FILE
    if [[ "$ARC_DIFF" -eq 0 ]]; then
        echo "Tidak ada gap archive log. Lanjutkan switchover." | tee -a $LOG_FILE
        break
    else
        echo "Masih ada ARC_DIFF > 0, tunggu 10 detik..." | tee -a $LOG_FILE
        sleep 10
    fi
done

# ================= STEP 2: USER CONFIRM =================
read -p "Lanjutkan switchover ke standby? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Switchover dibatalkan." | tee -a $LOG_FILE
    exit 1
fi

# ================= STEP 3: VERIFY SWITCHOVER =================
echo "[2] Verifikasi switchover..." | tee -a $LOG_FILE
sqlplus -S / as sysdba <<EOF | tee -a $LOG_FILE
ALTER DATABASE SWITCHOVER TO ${STANDBY_TNS} VERIFY;
EOF

# ================= STEP 4: EXECUTE SWITCHOVER =================
echo "[3] Melakukan switchover..." | tee -a $LOG_FILE
sqlplus -S / as sysdba <<EOF | tee -a $LOG_FILE
ALTER DATABASE SWITCHOVER TO ${STANDBY_TNS};
EOF

# ================= STEP 5: PRIMARY BARU (STANDBY LAMA) =================
echo "[4] Menangani primary baru (${STANDBY_HOST})..." | tee -a $LOG_FILE
ssh oracle@$STANDBY_HOST <<EOF | tee -a $LOG_FILE
export ORACLE_HOME=$ORACLE_HOME
export PATH=\$ORACLE_HOME/bin:\$PATH
export ORACLE_SID=orcl

sqlplus -S / as sysdba <<SQL

-- Jika masih MOUNTED, buka PRIMARY baru sebagai READ WRITE
DECLARE
    v_open_mode VARCHAR2(30);
BEGIN
    SELECT OPEN_MODE INTO v_open_mode FROM V\$DATABASE;
    IF v_open_mode='MOUNTED' THEN
        EXECUTE IMMEDIATE 'ALTER DATABASE OPEN READ WRITE';
    END IF;
END;
/
SQL
EOF

# ================= STEP 6: STANDBY BARU (PRIMARY LAMA) =================
echo "[5] Menangani standby baru (${PRIMARY_HOST})..." | tee -a $LOG_FILE
ssh oracle@$PRIMARY_HOST <<EOF | tee -a $LOG_FILE
export ORACLE_HOME=$ORACLE_HOME
export PATH=\$ORACLE_HOME/bin:\$PATH
export ORACLE_SID=orcl

sqlplus -S / as sysdba <<SQL
-- Startup standby baru
STARTUP MOUNT;

-- Buka standby sebagai READ ONLY
ALTER DATABASE OPEN READ ONLY;

-- Jalankan MRP
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

SQL
EOF

echo ""
echo "=======================================" | tee -a $LOG_FILE
echo "Switchover selesai. Primary baru READ WRITE, Standby baru READ ONLY + MRP aktif." | tee -a $LOG_FILE
echo "Semua langkah dicatat di $LOG_FILE"
echo "Cek database role di kedua server untuk verifikasi."
echo "=======================================" | tee -a $LOG_FILE

