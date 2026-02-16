#!/bin/bash

#---------------------
#  Konfigurasi Oracle
#---------------------
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_BASE ORACLE_HOME PATH

#---------------------
#  Pilih Instance
#---------------------
echo "🔍 Mendeteksi instance Oracle yang sedang aktif..."
ps -ef | grep pmon | grep -v grep | awk -F_ '{print $NF}' > /tmp/instance_list.txt

if [[ ! -s /tmp/instance_list.txt ]]; then
  echo "❌ Tidak ada instance Oracle yang terdeteksi."
  exit 1
fi

echo ""
echo "Daftar Instance Terdeteksi:"
i=1
declare -A SID_LIST
while read line; do
  echo "$i. $line"
  SID_LIST[$i]=$line
  ((i++))
done < /tmp/instance_list.txt

read -p "Pilih nomor instance: " pilih
ORACLE_SID=${SID_LIST[$pilih]}
export ORACLE_SID

if [[ -z "$ORACLE_SID" ]]; then
  echo "❌ Pilihan tidak valid."
  exit 1
fi

#---------------------
#  Informasi CPU dari OS
#---------------------
echo ""
echo "📊 Informasi CPU Load dari OS (top 5 proses Oracle)..."
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | grep ora_ | head -n 5

echo ""
echo "📈 Rata-rata Load CPU (1, 5, 15 menit):"
uptime | awk -F'load average:' '{ print "Load Average:" $2 }'

#---------------------
#  CPU Usage Total (%) dari OS
#---------------------
echo ""
echo "🧠 Penggunaan CPU Total saat ini:"
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk -F',' '{for(i=1;i<=NF;i++){if($i~/%id/){print $i}}}' | grep -o '[0-9.]\+')

if [[ -n "$CPU_IDLE" ]]; then
  CPU_USED=$(echo "scale=2; 100 - $CPU_IDLE" | bc)
  echo "Penggunaan CPU saat ini: ${CPU_USED}% dari 100%"
else
  echo "❌ Tidak dapat mendeteksi CPU Idle dari perintah top."
fi

#---------------------
#  Penggunaan CPU oleh Session Oracle
#---------------------
echo ""
echo "🔧 Penggunaan CPU oleh Session Oracle (v\$sess_time_model)..."
sqlplus -s / as sysdba <<EOF
SET LINESIZE 200
COL username FORMAT A15
COL sid FORMAT 9999
COL cpu_sec FORMAT 999999.99
SELECT s.sid, s.username,
       ROUND(VALUE/1000000, 2) AS cpu_sec
FROM v\$session s
JOIN v\$sess_time_model tm ON s.sid = tm.sid
WHERE stat_name = 'DB CPU'
AND s.status = 'ACTIVE'
AND s.username IS NOT NULL
ORDER BY cpu_sec DESC;
EOF

#---------------------
#  Session Memory Usage (PGA & UGA)
#---------------------
echo ""
echo "🧠 Session dengan Penggunaan Memory (PGA/UGA) Tertinggi:"
sqlplus -s / as sysdba <<EOF
SET LINESIZE 200
COL username FORMAT A15
COL sid FORMAT 9999
COL program FORMAT A25
COL pga FORMAT 999,999,999
COL uga FORMAT 999,999,999

SELECT s.sid,
       s.username,
       s.program,
       MAX(CASE WHEN sn.name = 'session pga memory' THEN ss.value END) AS pga,
       MAX(CASE WHEN sn.name = 'session uga memory' THEN ss.value END) AS uga
FROM   v\$session s
JOIN   v\$sesstat ss ON s.sid = ss.sid
JOIN   v\$statname sn ON ss.statistic# = sn.statistic#
WHERE  s.username IS NOT NULL
AND    s.status = 'ACTIVE'
GROUP BY s.sid, s.username, s.program
ORDER BY pga DESC FETCH FIRST 5 ROWS ONLY;
EOF

#---------------------
#  Footer Navigasi
#---------------------
echo ""
echo "🕓 Proses selesai pada: $(date '+%d-%m-%Y %H:%M:%S')"
echo ""
echo "Tekan [L2] untuk kembali ke menu L2 Tools atau [Q] untuk keluar."

read -t 30 -n 2 key
if [[ "$key" =~ ^[Ll]2$ ]]; then
  exec /home/oracle/noxious@scripts/automation/L2@action/L2@action.sh
elif [[ "$key" =~ ^[Qq]$ ]]; then
  echo ""
  echo "Keluar dari CPU Usage Tool."
  exit 0
else
  echo ""
  echo "⏹ Waktu habis atau pilihan tidak valid. Keluar dari tool."
  exit 0
fi

