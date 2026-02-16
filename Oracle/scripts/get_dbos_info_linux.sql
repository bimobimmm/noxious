#!/bin/sh
# Fungsi : Mengumpulkan informasi database beserta informasi sistem operasi
# Prasyarat : 1. Environment ORACLE_HOME dan ORACLE SID telah terdefinisikan
#             2. Untuk database, dijalankan dari user database yang mempunyai privilege select on dictionary views (dalam script ini menggunakan user
# sys)
#                dan untuk sistem operasi, dijalankan dari user sistem operasi yang mempunyai group oinstall
# Penggunaan : 1. Membuat folder baru
#              2. Copy file get_dbos_info_mig.sh dan collect_db_info_mig.sql ke dalam folder yang baru dibuat
#              3. Memberi privilege eksekusi kepada file get_dbos_info_mig.sh = chmod u+x get_db_info_mig.sh
#              4. Eksekusi file get_dbos_info_mig.sh = ./get_dbos_info_mig.sh
# versi : 1.0 -- untuk operating sistem LINUX
# MGS - 2017

. /home/oracle/.orcl_profile
$ORACLE_HOME/bin/sqlplus / as sysdba @collect_db_info_mig.sql
$ORACLE_HOME/bin/sqlplus / as sysdba @verify_objects_mig_1.2.sql
$ORACLE_HOME/bin/sqlplus / as sysdba @col.sql
$ORACLE_HOME/OPatch/opatch lsinventory -detail >> OpatchInfo_$ORACLE_SID.lstmig
echo "=== O/S info ===" >> OSInfo.lstmig
more /etc/os-release >> OSInfo.lstmig
more /etc/oracle-release >> OSInfo.lstmig
more /etc/redhat-release >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== Kernel info ===" >> OSInfo.lstmig
uname -a >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== system space info ===" >> OSInfo.lstmig
df -h >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== CPU info ===" >> OSInfo.lstmig
more /proc/cpuinfo >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== CPU Socket info ===" >> OSInfo.lstmig
echo $(($(grep "^physical id" /proc/cpuinfo | awk '{print $4}' | sort -un | tail -1)+1)) >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== Memory info ===" >> OSInfo.lstmig
more /proc/meminfo >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== oratab info ===" >> OSInfo.lstmig
tail /etc/oratab >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== pmon info ===" >> OSInfo.lstmig
ps -ef | grep pmon >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== crontab info ===" >> OSInfo.lstmig
crontab -l >> OSInfo.lstmig
HSTNAME=`hostname`
DATE=`date`
tar cvf DBOSInfo_$ORACLE_SID-at-$HSTNAME.tar *.lstmig COLLECT_DATA_PM*
rm *.lstmig COLLECT_DATA_PM*

. /home/oracle/.orcl1_profile
$ORACLE_HOME/bin/sqlplus / as sysdba @collect_db_info_mig.sql
$ORACLE_HOME/bin/sqlplus / as sysdba @verify_objects_mig_1.2.sql
$ORACLE_HOME/bin/sqlplus / as sysdba @col_asm.sql
$ORACLE_HOME/OPatch/opatch lsinventory -detail >> OpatchInfo_$ORACLE_SID.lstmig
echo "=== O/S info ===" >> OSInfo.lstmig
more /etc/os-release >> OSInfo.lstmig
more /etc/oracle-release >> OSInfo.lstmig
more /etc/redhat-release >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== Kernel info ===" >> OSInfo.lstmig
uname -a >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== system space info ===" >> OSInfo.lstmig
df -h >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== CPU info ===" >> OSInfo.lstmig
more /proc/cpuinfo >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== CPU Socket info ===" >> OSInfo.lstmig
echo $(($(grep "^physical id" /proc/cpuinfo | awk '{print $4}' | sort -un | tail -1)+1)) >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== Memory info ===" >> OSInfo.lstmig
more /proc/meminfo >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== oratab info ===" >> OSInfo.lstmig
tail /etc/oratab >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== pmon info ===" >> OSInfo.lstmig
ps -ef | grep pmon >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== crontab info ===" >> OSInfo.lstmig
crontab -l >> OSInfo.lstmig
echo "=== cluster info ===" >> OSInfo.lstmig
ps -ef | grep pmon >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== hugepages info ===" >> OSInfo.lstmig
grep ^Huge /proc/meminfo >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== asmcmd lsdg ===" >> OSInfo.lstmig
asmcmd lsdg;date >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
HSTNAME=`hostname`
DATE=`date`
tar cvf DBOSInfo_$ORACLE_SID-at-$HSTNAME.tar *.lstmig COLLECT_DATA_PM*
rm *.lstmig COLLECT_DATA_PM*

. /home/oracle/.dbrtgs_profile
$ORACLE_HOME/bin/sqlplus / as sysdba @collect_db_info_mig.sql
$ORACLE_HOME/bin/sqlplus / as sysdba @verify_objects_mig_1.2.sql
$ORACLE_HOME/bin/sqlplus / as sysdba @col_asm.sql
$ORACLE_HOME/OPatch/opatch lsinventory -detail >> OpatchInfo_$ORACLE_SID.lstmig
echo "=== O/S info ===" >> OSInfo.lstmig
more /etc/os-release >> OSInfo.lstmig
more /etc/oracle-release >> OSInfo.lstmig
more /etc/redhat-release >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== Kernel info ===" >> OSInfo.lstmig
uname -a >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== system space info ===" >> OSInfo.lstmig
df -h >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== CPU info ===" >> OSInfo.lstmig
more /proc/cpuinfo >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== CPU Socket info ===" >> OSInfo.lstmig
echo $(($(grep "^physical id" /proc/cpuinfo | awk '{print $4}' | sort -un | tail -1)+1)) >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== Memory info ===" >> OSInfo.lstmig
more /proc/meminfo >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== oratab info ===" >> OSInfo.lstmig
tail /etc/oratab >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== pmon info ===" >> OSInfo.lstmig
ps -ef | grep pmon >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== crontab info ===" >> OSInfo.lstmig
crontab -l >> OSInfo.lstmig
echo "=== cluster info ===" >> OSInfo.lstmig
ps -ef | grep pmon >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== hugepages info ===" >> OSInfo.lstmig
grep ^Huge /proc/meminfo >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
echo "=== asmcmd lsdg ===" >> OSInfo.lstmig
asmcmd lsdg;date >> OSInfo.lstmig
echo " " >> OSInfo.lstmig
HSTNAME=`hostname`
DATE=`date`
tar cvf DBOSInfo_$ORACLE_SID-at-$HSTNAME.tar *.lstmig COLLECT_DATA_PM*
rm *.lstmig COLLECT_DATA_PM*

