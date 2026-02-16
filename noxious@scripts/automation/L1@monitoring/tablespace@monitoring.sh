#!/bin/bash

#---------------------
#  Konfigurasi Oracle
#---------------------
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#-------------------------------
#  Deteksi semua instance aktif
#-------------------------------
echo "Mendeteksi instance Oracle yang sedang aktif..."
ps -ef | grep pmon | grep -v grep | awk -F_ '{print $NF}' > /tmp/instance_list.txt

echo "Daftar Instance Terdeteksi:"
i=1
declare -A SID_LIST
while read line; do
  echo "$i. $line"
  SID_LIST[$i]=$line
  ((i++))
done < /tmp/instance_list.txt

echo -n "Pilih nomor instance untuk monitoring TABLESPACE: "
read pilih
ORACLE_SID=${SID_LIST[$pilih]}
export ORACLE_SID

if [ -z "$ORACLE_SID" ]; then
  echo "Pilihan tidak valid. Keluar."
  exit 1
fi

#---------------------
#  Warna ANSI
#---------------------
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

# Deteksi apakah CDB
pdb_name=""
check_pdb=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF FEEDBACK OFF VERIFY OFF
SELECT cdb FROM v\$database;
EXIT;
EOF
)

if [[ "$check_pdb" == "YES" ]]; then
  echo "Instance ini adalah CDB. Mendeteksi PDB yang terbuka..."
  sqlplus -s / as sysdba <<EOF
SET LINESIZE 150
COL name FOR A30
SELECT name FROM v\$pdbs WHERE open_mode = 'READ WRITE';
EOF
  echo -n "Masukkan nama PDB yang ingin dimonitoring: "
  read pdb_name
  info_msg="Monitoring PDB: $pdb_name"
else
  info_msg="Monitoring NON-CDB tanpa ALTER SESSION"
fi

#---------------------
#  Monitoring Loop
#---------------------
while true; do
  clear
  echo "Monitoring Tablespace Usage - Instance: $ORACLE_SID ${pdb_name:+(PDB: $pdb_name)}"
  echo "========================================================"
  echo ""
  echo ""
  echo "$info_msg"
  echo ""

  # Simpan output query ke file sementara
  sqlplus -s / as sysdba <<EOF > /tmp/tbs_monitor.txt
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 100
SET LINESIZE 300
${pdb_name:+ALTER SESSION SET CONTAINER=$pdb_name;}

SELECT df.tablespace_name,
       ROUND((df.totalspace - NVL(fs.freespace, 0))/1024/1024, 2) AS used_gb,
       ROUND(NVL(fs.freespace, 0)/1024/1024, 2) AS free_gb,
       ROUND(df.totalspace/1024/1024, 2) AS max_gb,
       ROUND(((df.totalspace - NVL(fs.freespace, 0))/df.totalspace)*100, 2) AS used_pct,
       df.autoextensible
FROM
  (SELECT tablespace_name,
          SUM(bytes) AS totalspace,
          CASE WHEN MAX(autoextensible) = 'YES' THEN 'YES' ELSE 'NO' END AS autoextensible
   FROM dba_data_files
   GROUP BY tablespace_name) df
LEFT JOIN
  (SELECT tablespace_name, SUM(bytes) AS freespace
   FROM dba_free_space
   GROUP BY tablespace_name) fs
ON df.tablespace_name = fs.tablespace_name
ORDER BY used_pct DESC;
EOF

  # Header manual
  echo -e "TABLESPACE         USED(GB)  FREE(GB)  MAX(GB)  USED(%)  AUTOEXT"
  echo -e "------------------ --------  --------  -------  -------  ---------"

  # Loop hasil dan beri warna
  while read -r line; do
    tbs=$(echo "$line" | awk '{print $1}')
    used=$(echo "$line" | awk '{print $2}')
    free=$(echo "$line" | awk '{print $3}')
    max=$(echo "$line" | awk '{print $4}')
    pct=$(echo "$line" | awk '{print $5}')
    autoext=$(echo "$line" | awk '{print $6}')

    [[ -z "$tbs" || "$tbs" == "TABLESPACE_NAME" ]] && continue

    if (( $(echo "$pct >= 90" | bc -l) )); then
      echo -e "${RED}$(printf '%-18s %8s %9s %8s %8s %10s' "$tbs" "$used" "$free" "$max" "$pct%" "$autoext")${RESET}"
    elif (( $(echo "$pct >= 80" | bc -l) )); then
      echo -e "${YELLOW}$(printf '%-18s %8s %9s %8s %8s %10s' "$tbs" "$used" "$free" "$max" "$pct%" "$autoext")${RESET}"
    else
      echo -e "$(printf '%-18s %8s %9s %8s %8s %10s' "$tbs" "$used" "$free" "$max" "$pct%" "$autoext")"
    fi
  done < /tmp/tbs_monitor.txt

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
    break
  fi

  sleep 30
done

