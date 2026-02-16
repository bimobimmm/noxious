#!/bin/bash
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#-----------------------------
# Deteksi Instance
#-----------------------------
echo "🔍 Mendeteksi instance Oracle yang sedang aktif..."
ps -ef | grep pmon | grep -v grep | awk -F_ '{print $NF}' > /tmp/instance_list.txt
echo ""
i=1; declare -A SID_LIST
while read line; do echo "$i. $line"; SID_LIST[$i]=$line; ((i++)); done < /tmp/instance_list.txt
read -p "Pilih nomor instance: " pilih
ORACLE_SID=${SID_LIST[$pilih]}
export ORACLE_SID
[[ -z "$ORACLE_SID" ]] && echo "❌ Pilihan tidak valid." && exit 1

#-----------------------------
# Deteksi CDB dan PDB
#-----------------------------
IS_CDB=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF FEEDBACK OFF
SELECT cdb FROM v\$database;
EOF
)

if [[ "$IS_CDB" =~ "YES" ]]; then
  echo ""; echo "🔍 CDB terdeteksi. Menampilkan daftar PDB..."
  sqlplus -s / as sysdba <<EOF > /tmp/pdb_list.txt
SET HEADING OFF FEEDBACK OFF
SELECT name FROM v\$pdbs WHERE open_mode='READ WRITE';
EOF
  i=1; declare -A PDB_LIST
  while read pdb; do [[ -n "$pdb" ]] && echo "$i. $pdb" && PDB_LIST[$i]=$pdb && ((i++)); done < /tmp/pdb_list.txt
  read -p "Pilih nomor PDB: " pdb_pick
  PDB_TARGET=${PDB_LIST[$pdb_pick]}
  [[ -z "$PDB_TARGET" ]] && echo "❌ PDB tidak valid." && exit 1
fi

#-----------------------------
# Tampilkan user non-system
#-----------------------------
echo ""
echo "📋 Daftar USER non-system yang tersedia:"
if [[ "$IS_CDB" =~ "YES" ]]; then
sqlplus -s / as sysdba <<EOF
ALTER SESSION SET CONTAINER=$PDB_TARGET;
SET PAGESIZE 100 LINESIZE 150
COL USERNAME FORMAT A30
SELECT username FROM dba_users
WHERE account_status='OPEN'
AND ORACLE_MAINTAINED = 'N'
AND username NOT IN ('SYS','SYSTEM','OUTLN','DBSNMP','XDB','GSMADMIN_INTERNAL')
ORDER BY username;
EOF
else
sqlplus -s / as sysdba <<EOF
SET PAGESIZE 100 LINESIZE 150
COL USERNAME FORMAT A30
SELECT username FROM dba_users
WHERE account_status='OPEN'
AND ORACLE_MAINTAINED = 'N'
AND username NOT IN ('SYS','SYSTEM','OUTLN','DBSNMP','XDB','GSMADMIN_INTERNAL')
ORDER BY username;
EOF
fi

#-----------------------------
# Tampilkan object TABLE terbaru
#-----------------------------
echo ""
echo "📜 Contoh TABEL yang tersedia (semua schema termasuk SYS):"
if [[ "$IS_CDB" =~ "YES" ]]; then
sqlplus -s / as sysdba <<EOF
ALTER SESSION SET CONTAINER=$PDB_TARGET;
SET PAGESIZE 50 LINESIZE 150
COL OWNER FORMAT A20
COL OBJECT_NAME FORMAT A30
SELECT owner, object_name, object_type FROM dba_objects
WHERE object_type = 'TABLE'
ORDER BY created DESC FETCH FIRST 20 ROWS ONLY;
EOF
else
sqlplus -s / as sysdba <<EOF
SET PAGESIZE 50 LINESIZE 150
COL OWNER FORMAT A20
COL OBJECT_NAME FORMAT A30
SELECT owner, object_name, object_type FROM dba_objects
WHERE object_type = 'TABLE'
ORDER BY created DESC FETCH FIRST 20 ROWS ONLY;
EOF
fi

#-----------------------------
# Input untuk Grant
#-----------------------------
echo ""
read -p "Masukkan nama user yang akan diberi akses: " GRANT_USER

echo ""
echo "🎯 Pilih target GRANT:"
echo " [1] Satu Objek" 
echo " [2] Semua Tabel milik schema tertentu (ALL TABLES IN SCHEMA)"
read -p "Pilih opsi (1/2): " TARGET_TYPE

if [[ "$TARGET_TYPE" == "1" ]]; then
  read -p "Masukkan nama objek (misal: HR.EMPLOYEES): " GRANT_OBJECT
  [[ -z "$GRANT_OBJECT" ]] && echo "❌ Objek tidak boleh kosong." && exit 1
fi

echo ""; echo "Jenis akses:"
echo " [1] SELECT   [2] INSERT   [3] UPDATE   [4] DELETE   [5] ALL"
read -p "Pilih opsi (1-5): " AKSES
case $AKSES in
  1) PERMISSION="SELECT" ;; 2) PERMISSION="INSERT" ;;
  3) PERMISSION="UPDATE" ;; 4) PERMISSION="DELETE" ;;
  5) PERMISSION="ALL" ;; *) echo "❌ Tidak valid."; exit 1 ;;
esac

#-----------------------------
# Eksekusi GRANT
#-----------------------------
echo ""; echo "🔐 Memberikan akses..."
if [[ "$IS_CDB" =~ "YES" ]]; then
  if [[ "$TARGET_TYPE" == "2" ]]; then
    read -p "Masukkan nama schema sumber (OWNER): " OWNER_SCHEMA
    sqlplus -s / as sysdba <<EOF
ALTER SESSION SET CONTAINER=$PDB_TARGET;
BEGIN
  FOR r IN (SELECT table_name FROM dba_tables WHERE owner=UPPER('$OWNER_SCHEMA')) LOOP
    EXECUTE IMMEDIATE 'GRANT $PERMISSION ON $OWNER_SCHEMA.' || r.table_name || ' TO $GRANT_USER';
  END LOOP;
END;
/
EXIT;
EOF
  else
    sqlplus -s / as sysdba <<EOF
ALTER SESSION SET CONTAINER=$PDB_TARGET;
GRANT $PERMISSION ON $GRANT_OBJECT TO $GRANT_USER;
EXIT;
EOF
  fi
else
  if [[ "$TARGET_TYPE" == "2" ]]; then
    read -p "Masukkan nama schema sumber (OWNER): " OWNER_SCHEMA
    sqlplus -s / as sysdba <<EOF
BEGIN
  FOR r IN (SELECT table_name FROM dba_tables WHERE owner=UPPER('$OWNER_SCHEMA')) LOOP
    EXECUTE IMMEDIATE 'GRANT $PERMISSION ON $OWNER_SCHEMA.' || r.table_name || ' TO $GRANT_USER';
  END LOOP;
END;
/
EXIT;
EOF
  else
    sqlplus -s / as sysdba <<EOF
GRANT $PERMISSION ON $GRANT_OBJECT TO $GRANT_USER;
EXIT;
EOF
  fi
fi

#-----------------------------
# Footer
#-----------------------------
echo ""
echo "✅ GRANT selesai untuk $GRANT_USER."
echo "🕓 $(date '+%d-%m-%Y %H:%M:%S')"
echo ""
echo "Tekan [L2] untuk kembali ke menu utama atau [Q] untuk keluar."
read -t 30 -n 2 key
[[ "$key" =~ [Ll][2] ]] && exec /home/oracle/noxious@scripts/automation/L2@action/L2@action.sh
[[ "$key" =~ [Qq] ]] && echo "Keluar dari Grant Tool." && exit 0

