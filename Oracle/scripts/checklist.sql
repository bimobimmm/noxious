
--Cek TOTAL SIZE DATABASE PER TABLESPACE
set pagesize 999;
set linesize 200;
column name format a20;
SELECT nvl(tablespace_name,'GRAND TOTAL') name,
 round(sum(curr_ts_size)/1024, 3) total_current_size_gb,
 round(sum(free_ts_size)/1024, 3) total_free_size_gb,
 round(sum(used_ts_size)/1024, 3) total_used_size_gb,
 round(sum(max_ts_size)/1024, 3) total_max_allocated_size_gb,
  DECODE(tablespace_name, NULL,      ROUND(100*SUM(free_ts_size)/SUM(curr_ts_size),2), SUM(ROUND(100 * (free_ts_size / curr_ts_size),2))) total_pct_free,
  DECODE(tablespace_name, NULL,      ROUND(100*SUM(used_ts_size)/SUM(curr_ts_size),2), SUM(ROUND(100 * (used_ts_size / curr_ts_size),2))) total_pct_used
FROM
(
(SELECT df.tablespace_name, 
(df.bytes - fs.bytes) / (1024 * 1024) used_ts_size,
df.bytes / (1024 * 1024) curr_ts_size,
df.maxbytes / (1024 * 1024) max_ts_size,
fs.bytes / (1024 * 1024) free_ts_size
FROM  
(select tablespace_name,
 sum(bytes) bytes
 from dba_free_space
 group by tablespace_name) fs,
 (select tablespace_name,
 sum(bytes) bytes,
 sum(decode(maxbytes, 0, bytes, maxbytes)) maxbytes
 from dba_data_files
 group by tablespace_name) df
WHERE fs.tablespace_name (+) = df.tablespace_name
GROUP BY df.tablespace_name,df.bytes,df.maxbytes,fs.bytes)
)
group by rollup(tablespace_name) --order by total_pct_used desc;


--Cek TOTAL SIZE DATABASE PER TABLESPACE TEMP
set pagesize 15;
set linesize 200;
column name format a20;
SELECT nvl(tablespace_name,'GRAND TOTAL') name,
 round(sum(curr_ts_size)/1024, 3) total_current_size_gb,
 round(sum(free_ts_size)/1024, 3) total_free_size_gb,
 round(sum(used_ts_size)/1024, 3) total_used_size_gb,
 round(sum(max_ts_size)/1024, 3) total_max_allocated_size_gb,
  DECODE(tablespace_name, NULL,      ROUND(100*SUM(free_ts_size)/SUM(curr_ts_size),2), SUM(ROUND(100 * (free_ts_size / curr_ts_size),2))) total_pct_free,
  DECODE(tablespace_name, NULL,      ROUND(100*SUM(used_ts_size)/SUM(curr_ts_size),2), SUM(ROUND(100 * (used_ts_size / curr_ts_size),2))) total_pct_used
FROM
(
(SELECT df.tablespace_name, 
NVL(fs.bytes / (1024 * 1024),0) used_ts_size,
df.bytes / (1024 * 1024) curr_ts_size,
df.maxbytes / (1024 * 1024) max_ts_size,
NVL((df.bytes - fs.bytes) / (1024 * 1024),0) free_ts_size
FROM  
(select tablespace_name,
 sum(BYTES_USED) bytes
 from v$temp_extent_pool
 group by tablespace_name) fs,
 (select tablespace_name,
 sum(bytes) bytes,
 sum(decode(maxbytes, 0, bytes, maxbytes)) maxbytes
 from dba_temp_files
 group by tablespace_name) df
WHERE fs.tablespace_name (+) = df.tablespace_name
GROUP BY df.tablespace_name,df.bytes,df.maxbytes,fs.bytes)
)
group by rollup(tablespace_name);


--Cek TOTAL SIZE DATABASE PER REDOLOG
set pagesize 15;
set linesize 200;
column REDOLOG_FILE_NAME format a50
SELECT nvl(MEMBER,'GRAND TOTAL') AS REDOLOG_FILE_NAME,
 round(sum(curr_rd_size)/1024, 3) total_current_size_gb
FROM
(
(SELECT b.MEMBER,
 a.GROUP#,
 a.THREAD#,
 a.bytes / (1024 * 1024) curr_rd_size
FROM  
(select GROUP#,THREAD#,
 sum(bytes) bytes
 from v$log
 group by GROUP#,THREAD#) a,
 (select MEMBER,
 GROUP#
 from v$logfile
 group by GROUP#,MEMBER) b
WHERE a.GROUP# (+) = b.GROUP#
GROUP BY b.MEMBER,a.GROUP#,a.THREAD#,a.bytes)
)
group by rollup(MEMBER);


column start_time format a25;	
column OUTPUT_DEVICE format a15;	
column TIME_TAKEN format a10;	
column OUTPUT_RATE format a12;	
set linesize 200;	
SELECT   TO_CHAR (j.start_time, 'MON DD, YYYY HH24:MI:SS') as start_time, j.status,	
		 ROUND ((j.input_bytes / 1024 / 1024 / 1024), 2) input_gb,	
		 ROUND ((j.output_bytes / 1024 / 1024 / 1024), 2) output_gb,	
		 j.input_type, j.output_device_type AS output_device,	
		 j.time_taken_display AS time_taken,	
		 j.output_bytes_per_sec_display AS output_rate	
	FROM v$rman_backup_job_details j	
	WHERE j.start_time > TRUNC (SYSDATE) - 21	
ORDER BY j.session_recid DESC;


col path format a30;	
col name format a30;	
col failgroup format a30;	
set linesize 200;	
SELECT NAME, ROUND ((space_limit / 1024 / 1024 / 1024), 2) AS space_limit_gb,	
	   ROUND ((space_used / 1024 / 1024 / 1024), 2) AS space_used_gb,	
	   ROUND (((space_limit - space_used) / 1024 / 1024 / 1024),2) AS free_space_gb,	
	   ROUND (((space_used / space_limit) * 100), 2) AS space_used_percent,	
	   ROUND ((((space_limit - space_used) / space_limit) * 100),2) AS free_space_percent,	
	   NUMBER_OF_FILES	
  FROM v$recovery_file_dest;



exit;
