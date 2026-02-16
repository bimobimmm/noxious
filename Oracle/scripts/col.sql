-- collect data PM 
-- DB configuration : RAC DB
-- ver 1.1

define logname=date
column clogname new_value logname
select 'COLLECT_DATA_PM_'||substr(instance_name,1,
 decode(dot,0,length(instance_name),dot-1))||'_'||
 to_char(sysdate, 'yyyymmdd') clogname
from (select instance_name, instr(instance_name, '.') dot from v$instance);
spool '&logname'

alter session set nls_date_format='DD-MON-YYYY HH24:MI:SS';

ttitle left "=== instance info ==="
set lines 999
col host_name format a27
col version format a10
col status format a7
col instance_name format a13
col db_status format a10
select instance_number inst_num, instance_name, host_name,version,status,startup_time,archiver,database_status db_status
from gv$instance where instance_number in ('1', '2');

ttitle left "=== version info ==="
select * from v$version;

ttitle left "=== redo group info ==="
set lines 125 pages 1000
col status format a10
select GROUP#, thread#, SEQUENCE#,BYTES/1024/1024 size_mb, ARCHIVED, status
from v$log
order by 1;

ttitle left "=== redo member info ==="

set lines 125 pages 1000
col member form a48
SELECT a.group#, a.member, b.thread#, b.bytes/1024/1024 as MB, a.status, a.type
FROM v$logfile a, v$log b WHERE a.group# = b.group#
ORDER BY a.group#;

ttitle left "=== archive log info ==="
archive log list;

ttitle left "=== sga info ==="
show parameter sga;

ttitle left "=== pga info ==="
show parameter pga;

ttitle left "=== sga info2 ==="
col name format a30
select inst_id, name, value/1024/1024/1024 sizegb from gv$pgastat
where name='aggregate PGA target parameter'
union
select inst_id, name, round(bytes/1024/1024/1024) sizegb from gv$sgainfo
where name ='Maximum SGA Size';

ttitle left "=== memory info ==="
show parameter memory;

ttitle left "=== TBS size info ==="
set pagesize 85
 select
   df.tablespace_name "Tablespace Name",
   df.totalspace "Total MB",
   (df.totalspace - fs.freespace) "Used MB",
   fs.freespace "Free MB",
   round(100 * (fs.freespace / df.totalspace),2) "Pct. Free"
from
   dba_tablespaces ts,
   (select tablespace_name,
        (sum(bytes) / 1048576) TotalSpace
      from dba_data_files
      group by tablespace_name) df,
   (select tablespace_name,
        (sum(bytes) / 1048576) FreeSpace
      from dba_free_space
      group by tablespace_name) fs
where
   ts.tablespace_name = fs.tablespace_name
and
   df.tablespace_name = fs.tablespace_name(+)
order by ts.tablespace_name;

set pagesize 85
select tablespace_name, round(sum(bytes/1024/1024)) from dba_data_files
    group by tablespace_name
   order by tablespace_name;


ttitle left "=== TBS Utilization info ==="

set linesize 200
set pagesize 100
COLUMN tablespace_name        format a25             heading 'Tablespace|(TBS)|Name'
COLUMN autoextensible         format a6              heading 'Can|Auto|Extend'
COLUMN files_in_tablespace    format 999             heading 'Files|In|TBS'
COLUMN total_tablespace_space format 99,999,999,999,999 heading 'Total|Current|TBS|Space'
COLUMN total_used_space       format 99,999,999,999,999 heading 'Total|Current|Used|Space'
COLUMN total_tablespace_free_space format 99,999,999,999,999 heading 'Total|Current|Free|Space'
COLUMN total_used_pct              format 999.99      heading 'Total|Current|Used|PCT'
COLUMN total_free_pct              format 999.99      heading 'Total|Current|Free|PCT'
COLUMN max_size_of_tablespace      format 99,999,999,999,999 heading 'TBS|Max|Size'
COLUMN total_auto_used_pct         format 999.99      heading 'Total|Max|Used|PCT'
COLUMN total_auto_free_pct         format 999.99      heading 'Total|Max|Free|PCT'
 
TTITLE left _date center Tablespace Space Utilization Status Report skip 2
 
WITH tbs_auto AS
     (SELECT DISTINCT tablespace_name, autoextensible
                 FROM dba_data_files
                WHERE autoextensible = 'YES'),
     files AS
     (SELECT   tablespace_name, COUNT (*) tbs_files,
               SUM (BYTES) total_tbs_bytes
          FROM dba_data_files
      GROUP BY tablespace_name),
     fragments AS
     (SELECT   tablespace_name, COUNT (*) tbs_fragments,
               SUM (BYTES) total_tbs_free_bytes,
               MAX (BYTES) max_free_chunk_bytes
          FROM dba_free_space
      GROUP BY tablespace_name),
     AUTOEXTEND AS
     (SELECT   tablespace_name, SUM (size_to_grow) total_growth_tbs
          FROM (SELECT   tablespace_name, SUM (maxbytes) size_to_grow
                    FROM dba_data_files
                   WHERE autoextensible = 'YES'
                GROUP BY tablespace_name
                UNION
                SELECT   tablespace_name, SUM (BYTES) size_to_grow
                    FROM dba_data_files
                   WHERE autoextensible = 'NO'
                GROUP BY tablespace_name)
      GROUP BY tablespace_name)
SELECT a.tablespace_name,
       CASE tbs_auto.autoextensible
          WHEN 'YES'
             THEN 'YES'
          ELSE 'NO'
       END AS autoextensible,
       files.tbs_files files_in_tablespace,
       files.total_tbs_bytes total_tablespace_space,
       (files.total_tbs_bytes - fragments.total_tbs_free_bytes
       ) total_used_space,
       fragments.total_tbs_free_bytes total_tablespace_free_space,
       (  (  (files.total_tbs_bytes - fragments.total_tbs_free_bytes)
           / files.total_tbs_bytes
          )
        * 100
       ) total_used_pct,
       ((fragments.total_tbs_free_bytes / files.total_tbs_bytes) * 100
       ) total_free_pct,
       AUTOEXTEND.total_growth_tbs max_size_of_tablespace,
       (  (  (  AUTOEXTEND.total_growth_tbs
              - (AUTOEXTEND.total_growth_tbs - fragments.total_tbs_free_bytes
                )
             )
           / AUTOEXTEND.total_growth_tbs
          )
        * 100
       ) total_auto_used_pct,
       (  (  (AUTOEXTEND.total_growth_tbs - fragments.total_tbs_free_bytes)
           / AUTOEXTEND.total_growth_tbs
          )
        * 100
       ) total_auto_free_pct
  FROM dba_tablespaces a, files, fragments, AUTOEXTEND, tbs_auto
WHERE a.tablespace_name = files.tablespace_name
   AND a.tablespace_name = fragments.tablespace_name
   AND a.tablespace_name = AUTOEXTEND.tablespace_name
   AND a.tablespace_name = tbs_auto.tablespace_name(+)
   Order by a.tablespace_name;

clear columns
-- TTITLE left ""

ttitle left '=== db size1 ==='
select sum(bytes/1024/1024/1024)
from dba_data_files;

ttitle left '=== db size2 ==='

set linesize 200
set pagesize 100
break on report
compute sum of size_mb on report
select tablespace_name nama, sum(bytes/1024/1024) size_mb
from dba_data_files
group by tablespace_name
union
select to_char(GROUP#) nama,(BYTES/1024/1024)*2 size_mb 
from v$log
order by nama;

ttitle left "=== I/O Statistik ==="
set linesize 999
set pagesize 999
col name for a56
col "Read %" for a10
col "Write %" for a10
select  NAME,
        PHYRDS "Physical Reads",
        to_char(round((PHYRDS / PD.PHYS_READS)*100,2)) "Read %",
        PHYWRTS "Physical Writes",
        to_char(round(PHYWRTS * 100 / PD.PHYS_WRTS,2)) "Write %",
        fs.PHYBLKRD+FS.PHYBLKWRT "Total Block I/O's"
from (
        select  sum(PHYRDS) PHYS_READS,
                sum(PHYWRTS) PHYS_WRTS
        from    v$filestat
        ) pd,
        v$datafile df,
        v$filestat fs
where   df.FILE# = fs.FILE#
order   by fs.PHYBLKRD+fs.PHYBLKWRT desc;

ttitle left "=== Generated Archivelog Per Day ==="
set pages 1050
select trunc(COMPLETION_TIME,'DD') Day, thread#, 
round(sum(BLOCKS*BLOCK_SIZE)/1024/1024/1024) GB,
count(*) Archives_Generated from v$archived_log 
group by trunc(COMPLETION_TIME,'DD'),thread# order by 1;

ttitle left "=== FRA info ==="
col NAME format A12;
select name, round(space_limit/1024/1024) "Size MB",		
		round(space_used/1024/1024) "Used MB",
		round((((space_limit/1024/1024)-(space_used/1024/1024))*100)/(space_limit/1024/1024),2) "% Free",
	round(((space_used/1024/1024)*100)/(space_limit/1024/1024),2) "% Used"
from v$recovery_file_dest order by name;

ttitle left "=== stale table info ==="
set pagesize 1250
select s.owner, s.table_name, s.stale_stats
from dba_tab_statistics s 
where s.owner not in
(
'ORACLE_OCM', 'OUTLN', 'REPOLINK', 'SYS', 'SYSMAN', 'SYSTEM', 'WMSYS', 'XDB', 'DBSNMP', 'MGMT_VIEW', 'MTSSYS', 'APPQOSSYS', 'XS$NULL', 'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR', 'SCOTT', 'DIP', 'MDDATA', 'OLAPSYS', 'SI_INFORMTN_SCHEMA', 'OWBSYS', 'OWBSYS_AUDIT', 'ORDPLUGINS', 'EXFSYS', 'ANONYMOUS', 'CTXSYS', 'ORDSYS', 'ORDDATA', 'MDSYS')
and s.table_name not like 'BIN$%'
and s.stale_stats='YES'
--group by s.owner, s.table_name, s.stale_stats
order by 1,2;

Ttitle le "=== DB backup status ==="
set lines 220
set pages 1000
col cf for 9,999
col df for 9,999
col elapsed_seconds heading "ELAPSED|SECONDS"
col i0 for 9,999
col i1 for 9,999
col l for 9,999
col dow for a10
col start_time format a20
col end_time format a20
col output_mbytes for 9,999,999 heading "OUTPUT|MBYTES"
col session_recid for 999999 heading "SESSION|RECID"
col session_stamp for 99999999999 heading "SESSION|STAMP"
col status for a10 trunc
col time_taken_display for a10 heading "TIME|TAKEN"
col output_instance for 9999 heading "OUT|INST"
select
  j.session_recid, j.session_stamp,
  to_char(j.start_time, 'yyyy-mm-dd hh24:mi:ss') start_time,
  to_char(j.end_time, 'yyyy-mm-dd hh24:mi:ss') end_time,
  (j.output_bytes/1024/1024) output_mbytes, j.status, j.input_type,
  decode(to_char(j.start_time, 'd'), 1, 'Sunday', 2, 'Monday',
                                     3, 'Tuesday', 4, 'Wednesday',
                                     5, 'Thursday', 6, 'Friday',
                                     7, 'Saturday') dow,
  j.elapsed_seconds, j.time_taken_display,
  x.cf, x.df, x.i0, x.i1, x.l,
  ro.inst_id output_instance
from V$RMAN_BACKUP_JOB_DETAILS j
  left outer join (select
                     d.session_recid, d.session_stamp,
                     sum(case when d.controlfile_included = 'YES' then d.pieces else 0 end) CF,
                     sum(case when d.controlfile_included = 'NO'
                               and d.backup_type||d.incremental_level = 'D' then d.pieces else 0 end) DF,
                     sum(case when d.backup_type||d.incremental_level = 'D0' then d.pieces else 0 end) I0,
                     sum(case when d.backup_type||d.incremental_level = 'I1' then d.pieces else 0 end) I1,
                     sum(case when d.backup_type = 'L' then d.pieces else 0 end) L
                   from
                     V$BACKUP_SET_DETAILS d
                     join V$BACKUP_SET s on s.set_stamp = d.set_stamp and s.set_count = d.set_count
                   where s.input_file_scan_only = 'NO'
                   group by d.session_recid, d.session_stamp) x
    on x.session_recid = j.session_recid and x.session_stamp = j.session_stamp
  left outer join (select o.session_recid, o.session_stamp, min(inst_id) inst_id
                   from GV$RMAN_OUTPUT o
                   group by o.session_recid, o.session_stamp)
    ro on ro.session_recid = j.session_recid and ro.session_stamp = j.session_stamp
where j.start_time > trunc(sysdate)-30
order by j.start_time;

ttitle left "=== Backup Details ==="
set pages 9999
set linesize 150
col status for a23
col start_time format a20
col end_time format a20
select sid, object_type, status,
round((end_time - start_time) * 24 * 60, 2) duration_minutes,
to_char(start_time, 'mm/dd/yyyy hh:mi:ss') start_time,
to_char(end_time, 'mm/dd/yyyy hh:mi:ss') end_time,
round((input_bytes/(1024*1024*1024)),2) input_gb,
round((output_bytes/(1024*1024*1024)),2) output_gb
from v$rman_status
where operation = 'BACKUP'
order by start_time;

ttitle left "=== tempfile info ==="
set pages 99
select tablespace_name nama, sum(bytes/1024/1024) size_mb
from dba_temp_files
group by tablespace_name;

ttitle left "=== jumlah datafile ==="
select sum(bytes/1024/1024/1024)
from dba_data_files;

clear columns

ttitle left "=== DG log transport info ==="
col dest_id for 9999
col error for a15
select dest_id, error, status, recovery_mode from v$archive_dest_status where dest_id in ('1','2');


ttitle left "=== DG primary DB maxlog ==="
SELECT MAX(SEQUENCE#), THREAD# FROM V$ARCHIVED_LOG WHERE RESETLOGS_CHANGE# = (select resetlogs_change# from v$database)GROUP BY THREAD#;
        

ttitle left "=== DG standby DB log apply - 1 ==="
set linesize 150
set pagesize 35
select arc.dest_id, decode(arc.dest_id,'1','PRIMARY-DB','2','STANDBY-DB') DB, arc.thread#, arc.sequence#, arc.applied,  arc.deleted, arc.completion_time from
(select dest_id, sequence#, applied, thread#, deleted, completion_time from v$archived_log
where dest_id in ('2')
and RESETLOGS_change# = (select resetlogs_change# from v$database)
order by sequence# desc, dest_id ) arc
where rownum <= 10
order by sequence# asc;


ttitle left "=== DG standby DB log apply - 2 ==="
set pagesize 35
set linesize 150
select arc.dest_id, decode(arc.dest_id,'1','PRIMARY-DB','2','STANDBY-DB') DB, arc.thread#, arc.sequence#, arc.applied,  arc.deleted, arc.completion_time from
(select dest_id, sequence#, applied, thread#, deleted, completion_time from v$archived_log
where dest_id in ('1','2')
and RESETLOGS_change# = (select resetlogs_change# from v$database)
order by sequence# desc, dest_id ) arc
where rownum <= 30
order by rownum desc;

-- SET NEWPAGE 0 VERIFY OFF
SET PAGES 10000 lines 153
COLUMN name  format a40
COLUMN value format a50
COLUMN description format a60 word_wrapped
Ttitle le "=== init.ora parameter listing ==="
SELECT   NAME, VALUE, description
    FROM v$parameter
ORDER BY NAME;
CLEAR COLUMNS
--SET VERIFY ON termout on PAGES 22 lines 80
--UNDEF output;


Ttitle le "=== DB registry info ==="
SET lines 200
col COMP_NAME format a40
col VERSION format a20
col STATUS format a10
col NAMESPACE format a10
col CONTROL format a15
col SCHEMA format a15
select COMP_NAME, VERSION, STATUS, MODIFIED, NAMESPACE, CONTROL, SCHEMA from dba_registry
order by 1;

spool off;

exit;