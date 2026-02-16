#!/bin/bash
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

# Pilih instance
echo "🔍 Mendeteksi instance Oracle yang sedang aktif..."
ps -ef | grep pmon | grep -v grep | awk -F_ '{print $NF}' > /tmp/instance_list.txt
echo ""; i=1; declare -A SID_LIST
while read line; do echo "$i. $line"; SID_LIST[$i]=$line; ((i++)); done < /tmp/instance_list.txt
read -p "Pilih nomor instance: " pilih
ORACLE_SID=${SID_LIST[$pilih]}
export ORACLE_SID
[[ -z "$ORACLE_SID" ]] && echo "❌ Pilihan tidak valid." && exit 1

# Deteksi PDB
IS_CDB=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF FEEDBACK OFF
SELECT cdb FROM v\$database;
EOF
)
if [[ "$IS_CDB" =~ "YES" ]]; then
  echo ""; echo "🔍 CDB terdeteksi. Menampilkan daftar PDB..."
  sqlplus -s / as sysdba <<EOF > /tmp/pdb_list.txt
SET HEADING OFF FEEDBACK OFF
SELECT name FROM v\$pdbs WHERE open_mode = 'READ WRITE';
EOF
  i=1; declare -A PDB_LIST
  while read pdb; do [[ -n "$pdb" ]] && echo "$i. $pdb" && PDB_LIST[$i]=$pdb && ((i++)); done < /tmp/pdb_list.txt
  read -p "Pilih nomor PDB: " pdb_pick
  PDB_TARGET=${PDB_LIST[$pdb_pick]}
  [[ -z "$PDB_TARGET" ]] && echo "❌ PDB tidak valid." && exit 1
  export CONN_TARGET="sqlplus -s /@\"$PDB_TARGET\" as sysdba"
else
  export CONN_TARGET="sqlplus -s / as sysdba"
fi

# Input
echo ""
read -p "Masukkan nama user yang akan dicabut aksesnya: " REVOKE_USER
read -p "Masukkan nama objek (misal: HR.EMPLOYEES): " REVOKE_OBJECT
echo ""; echo "Jenis akses:"
echo " [1] SELECT   [2] INSERT   [3] UPDATE   [4] DELETE   [5] ALL"
read -p "Pilih opsi (1-5): " AKSES
case $AKSES in
  1) PERMISSION="SELECT" ;; 2) PERMISSION="INSERT" ;; 3) PERMISSION="UPDATE" ;;
  4) PERMISSION="DELETE" ;; 5) PERMISSION="ALL" ;; *) echo "❌ Tidak valid."; exit 1 ;;
esac

# Eksekusi
echo ""; echo "🔐 REVOKE $PERMISSION ON $REVOKE_OBJECT FROM $REVOKE_USER"
$CONN_TARGET <<EOF
REVOKE $PERMISSION ON $REVOKE_OBJECT FROM $REVOKE_USER;
EOF

read -p "❓ Cabut juga CREATE SESSION? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  echo "🚫 Mencabut CREATE SESSION..."
  $CONN_TARGET <<EOF
  REVOKE CREATE SESSION FROM $REVOKE_USER;
EOF
fi

echo ""; echo "✅ Revoke selesai."
echo "🕓 $(date '+%d-%m-%Y %H:%M:%S')"
echo ""; echo "Tekan [L1] untuk kembali ke menu utama atau [Q] untuk keluar."
read -t 30 -n 2 key
[[ "$key" =~ [Ll][1] ]] && exec /home/oracle/noxious@scripts/automation/L1@monitoring/noxious@monitoring.sh
[[ "$key" =~ [Qq] ]] && echo "Keluar dari Revoke Tool." && exit 0

