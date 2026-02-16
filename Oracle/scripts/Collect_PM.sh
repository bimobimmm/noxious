#!/bin/bash

# Sesuaikan dengan kredensial Oracle Anda
ORACLE_SID=orcl
ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1/ORCL
export ORACLE_SID ORACLE_HOME PATH=$ORACLE_HOME/bin:$PATH

# Tentukan nama file output dengan format .lst
OUTPUT_FILE="COLLECT_PM_INFO_EDW.lst"

# Eksekusi Query di SQL*Plus dan simpan output ke file
sqlplus -s / as sysdba <<EOF > "$OUTPUT_FILE"
SET LINESIZE 150
SET PAGESIZE 100
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT
PROMPT =====================================================================
PROMPT === Redo Log Members ===
PROMPT =====================================================================
PROMPT

COLUMN MEMBER FORMAT A80
SELECT GROUP#, MEMBER, IS_RECOVERY_DEST_FILE FROM V\$LOGFILE ORDER BY GROUP#;

PROMPT
PROMPT =====================================================================
PROMPT === Redo Log Groups ===
PROMPT =====================================================================
PROMPT

COLUMN STATUS FORMAT A12
SELECT GROUP#, THREAD#, SEQUENCE#, BYTES/1024/1024 AS SIZE_MB, MEMBERS, STATUS FROM V\$LOG ORDER BY GROUP#;

PROMPT
PROMPT =====================================================================
PROMPT === Instance Information ===
PROMPT =====================================================================
PROMPT

COLUMN INSTANCE_NAME FORMAT A12
COLUMN HOST_NAME FORMAT A30
COLUMN VERSION FORMAT A12
COLUMN STATUS FORMAT A10
COLUMN STARTUP_TIME FORMAT A20
COLUMN DATABASE_STATUS FORMAT A10
SELECT INSTANCE_NAME, HOST_NAME, VERSION, STATUS, STARTUP_TIME, DATABASE_STATUS FROM V\$INSTANCE;

PROMPT
PROMPT =====================================================================
PROMPT === FRA Information ===
PROMPT =====================================================================
PROMPT

COLUMN NAME FORMAT A40
COLUMN "Size MB" FORMAT 999,999,999
COLUMN "Used MB" FORMAT 999,999,999.99
COLUMN "% Free" FORMAT 999.99
COLUMN "% Used" FORMAT 999.99

SELECT NAME, 
       SPACE_LIMIT / 1024 / 1024 AS "Size MB", 
       ROUND(SPACE_USED / 1024 / 1024, 2) AS "Used MB", 
       ROUND((SPACE_LIMIT - SPACE_USED) / SPACE_LIMIT * 100, 2) AS "% Free", 
       ROUND((SPACE_USED / SPACE_LIMIT) * 100, 2) AS "% Used"
FROM V\$RECOVERY_FILE_DEST;

PROMPT
PROMPT =====================================================================
PROMPT === Size Database Check  ===
PROMPT =====================================================================
PROMPT

SELECT ROUND(SUM(BYTES) / 1024 / 1024 / 1024, 2) AS "Database Size (GB)" FROM DBA_DATA_FILES;

PROMPT
PROMPT =====================================================================
PROMPT === SGA Information  ===
PROMPT =====================================================================
PROMPT

show parameter sga_target;

PROMPT
PROMPT =====================================================================
PROMPT === PGA Information  ===
PROMPT =====================================================================
PROMPT

show parameter pga_aggregate_target;

EXIT;
EOF

echo "OUTPUT DISIMPAN DALAM FILE: $OUTPUT_FILE"

