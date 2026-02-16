-- collect data PM 
-- DB configuration : RAC DB
-- ver 1.2

define logname=date
column clogname new_value logname
select 'COLLECT_DATA_PM_'||substr(instance_name,1,
 decode(dot,0,length(instance_name),dot-1))||'_'||
 to_char(sysdate, 'yyyymmdd') clogname
from (select instance_name, instr(instance_name, '.') dot from v$instance);
spool '&logname'

alter session set nls_date_format='DD-MON-YYYY HH24:MI:SS';

ttitle left "=== utilisasi disk ==="
SET SERVEROUTPUT ON
SET LINES 155
SET PAGES 0
SET TRIMSPOOL ON

DECLARE
   v_num_disks    NUMBER;
   v_group_number   NUMBER;
   v_max_total_mb   NUMBER;

   v_required_free_mb   NUMBER;
   v_usable_mb      NUMBER;
   v_cell_usable_mb   NUMBER;
   v_one_cell_usable_mb   NUMBER;
   v_enuf_free      BOOLEAN := FALSE;
   v_enuf_free_cell   BOOLEAN := FALSE;

   v_req_mirror_free_adj_factor   NUMBER := 1.10;
   v_req_mirror_free_adj         NUMBER := 0;
   v_one_cell_req_mir_free_mb     NUMBER  := 0;

   v_disk_desc      VARCHAR(10) := 'SINGLE';
   v_offset      NUMBER := 50;

   v_db_version   VARCHAR2(8);
   v_inst_name    VARCHAR2(1);

   v_cfc_fail_msg VARCHAR2(152);

BEGIN

   SELECT substr(version,1,8), substr(instance_name,1,1)    INTO v_db_version, v_inst_name    FROM v$instance;

   IF v_inst_name <> '+' THEN
      DBMS_OUTPUT.PUT_LINE('ERROR: THIS IS NOT AN ASM INSTANCE!  PLEASE LOG ON TO AN ASM INSTANCE AND RE-RUN THIS SCRIPT.');
      GOTO the_end;
   END IF;

    DBMS_OUTPUT.PUT_LINE('------ DISK and CELL Failure Diskgroup Space Reserve Requirements  ------');
    DBMS_OUTPUT.PUT_LINE(' This procedure determines how much space you need to survive a DISK or CELL failure. It also shows the usable space ');
    DBMS_OUTPUT.PUT_LINE(' available when reserving space for disk or cell failure.  ');
    DBMS_OUTPUT.PUT_LINE('.  .  .');
    DBMS_OUTPUT.PUT_LINE(' Description of Derived Values:');
    DBMS_OUTPUT.PUT_LINE(' One Cell Required Mirror Free MB : Required Mirror Free MB to permit successful rebalance after losing largest CELL regardless of redundancy type');
    DBMS_OUTPUT.PUT_LINE(' Disk Required Mirror Free MB     : Space needed to rebalance after loss of single or double disk failure (for normal or high redundancy)');
    DBMS_OUTPUT.PUT_LINE(' Disk Usable File MB              : Usable space available after reserving space for disk failure and accounting for mirroring');
    DBMS_OUTPUT.PUT_LINE(' Cell Usable File MB              : Usable space available after reserving space for SINGLE cell failure and accounting for mirroring');
   DBMS_OUTPUT.PUT_LINE('.  .  .');

   IF (v_db_version = '11.2.0.3') OR (v_db_version = '11.2.0.4') OR (v_db_version = '12.1.0.1')  THEN
      v_req_mirror_free_adj_factor := 1.10;
      DBMS_OUTPUT.PUT_LINE('ASM Version: '||v_db_version);
   ELSE
      v_req_mirror_free_adj_factor := 1.5;
      DBMS_OUTPUT.PUT_LINE('ASM Version: '||v_db_version||'  - WARNING DISK FAILURE COVERAGE ESTIMATES HAVE NOT BEEN VERIFIED ON THIS VERSION!');
   END IF;

   DBMS_OUTPUT.PUT_LINE('.  .  .');
-- Set up headings
     DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------------------------------------------------------------------');
      DBMS_OUTPUT.PUT('|          ');
      DBMS_OUTPUT.PUT('|         ');
      DBMS_OUTPUT.PUT('|     ');
      DBMS_OUTPUT.PUT('|          ');
      DBMS_OUTPUT.PUT('|            ');
      DBMS_OUTPUT.PUT('|            ');
      DBMS_OUTPUT.PUT('|            ');
      DBMS_OUTPUT.PUT('|Cell Req''d  ');
      DBMS_OUTPUT.PUT('|Disk Req''d  ');
      DBMS_OUTPUT.PUT('|            ');
      DBMS_OUTPUT.PUT('|            ');
      DBMS_OUTPUT.PUT('|    ');
      DBMS_OUTPUT.PUT('|    ');
      DBMS_OUTPUT.PUT('|       ');
      DBMS_OUTPUT.PUT_Line('|');
      DBMS_OUTPUT.PUT('|          ');
      DBMS_OUTPUT.PUT('|DG       ');
      DBMS_OUTPUT.PUT('|Num  ');
      DBMS_OUTPUT.PUT('|Disk Size ');
      DBMS_OUTPUT.PUT('|DG Total    ');
      DBMS_OUTPUT.PUT('|DG Used     ');
      DBMS_OUTPUT.PUT('|DG Free     ');
      DBMS_OUTPUT.PUT('|Mirror Free ');
      DBMS_OUTPUT.PUT('|Mirror Free ');
      DBMS_OUTPUT.PUT('|Disk Usable ');
      DBMS_OUTPUT.PUT('|Cell Usable ');
      DBMS_OUTPUT.PUT('|    ');
      DBMS_OUTPUT.PUT('|    ');
      DBMS_OUTPUT.PUT_LINE('|PCT    |');
      DBMS_OUTPUT.PUT('|DG Name   ');
      DBMS_OUTPUT.PUT('|Type     ');
      DBMS_OUTPUT.PUT('|Disks');
      DBMS_OUTPUT.PUT('|MB        ');
      DBMS_OUTPUT.PUT('|MB          ');
      DBMS_OUTPUT.PUT('|MB          ');
      DBMS_OUTPUT.PUT('|MB          ');
      DBMS_OUTPUT.PUT('|MB          ');
      DBMS_OUTPUT.PUT('|MB          ');
      DBMS_OUTPUT.PUT('|File MB     ');
      DBMS_OUTPUT.PUT('|File MB     ');
      DBMS_OUTPUT.PUT('|DFC ');
      DBMS_OUTPUT.PUT('|CFC ');
      DBMS_OUTPUT.PUT_LINE('|Util   |');
     DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------------------------------------------------------------------');

   FOR dg IN (SELECT name, type, group_number, total_mb, free_mb, required_mirror_free_mb FROM v$asm_diskgroup ORDER BY name) LOOP

      v_enuf_free := FALSE;

     v_req_mirror_free_adj := dg.required_mirror_free_mb * v_req_mirror_free_adj_factor;

      -- Find largest amount of space allocated to a cell
      SELECT sum(disk_cnt), max(max_total_mb), max(sum_total_mb)*v_req_mirror_free_adj_factor
     INTO v_num_disks, v_max_total_mb, v_one_cell_req_mir_free_mb
      FROM (SELECT count(1) disk_cnt, max(total_mb) max_total_mb, sum(total_mb) sum_total_mb
      FROM v$asm_disk
     WHERE group_number = dg.group_number
     GROUP BY failgroup);

      -- Eighth Rack
      IF dg.type = 'NORMAL' THEN

         -- Eighth Rack
         IF (v_num_disks < 36) THEN
            -- Use eqn: y = 1.21344 x+ 17429.8
            v_required_free_mb :=  1.21344 * v_max_total_mb + 17429.8;
            IF dg.free_mb > v_required_free_mb THEN v_enuf_free := TRUE; END IF;
         -- Quarter Rack
         ELSIF (v_num_disks >= 36 AND v_num_disks < 84) THEN
            -- Use eqn: y = 1.07687 x+ 19699.3
                        -- Revised 2/21/14 for 11.2.0.4 to use eqn: y=0.803199x + 156867, more space but safer
            v_required_free_mb := 0.803199 * v_max_total_mb + 156867;
            IF dg.free_mb > v_required_free_mb THEN v_enuf_free := TRUE; END IF;
         -- Half Rack
         ELSIF (v_num_disks >= 84 AND v_num_disks < 168) THEN
            -- Use eqn: y = 1.02475 x+53731.3
            v_required_free_mb := 1.02475 * v_max_total_mb + 53731.3;
            IF dg.free_mb > v_required_free_mb THEN v_enuf_free := TRUE; END IF;
         -- Full rack is most conservative, it will be default
         ELSE
            -- Use eqn: y = 1.33333 x+83220.
            v_required_free_mb := 1.33333 * v_max_total_mb + 83220;
            IF dg.free_mb > v_required_free_mb THEN v_enuf_free := TRUE; END IF;

         END IF;

         -- DISK usable file MB
         v_usable_mb := ROUND((dg.free_mb - v_required_free_mb)/3);
         v_disk_desc := 'ONE disk';

         -- CELL usable file MB
         v_cell_usable_mb := ROUND( (dg.free_mb - v_one_cell_req_mir_free_mb)/3 );
         v_one_cell_usable_mb := v_cell_usable_mb;

      ELSE
         -- NORMAL redundancy

         -- Eighth Rack
         IF (v_num_disks <= 18) THEN
            -- Use eqn: y = 4x + 0
                        -- Updated for 11.2.0.4 to higher value:  y = 3.84213x + 84466.4
            v_required_free_mb :=  3.84213 * v_max_total_mb + 84466.4;
            IF dg.free_mb > v_required_free_mb THEN v_enuf_free := TRUE; END IF;
         -- Quarter Rack
         ELSIF (v_num_disks > 18 AND v_num_disks <= 36) THEN
            -- Use eqn: y = 3.87356 x+417692.
            v_required_free_mb := 3.87356 * v_max_total_mb + 417692;
            IF dg.free_mb > v_required_free_mb THEN v_enuf_free := TRUE; END IF;
         -- Half Rack
         ELSIF (v_num_disks > 36 AND v_num_disks <= 84) THEN
            -- Use eqn: y = 2.02222 x+56441.6
            v_required_free_mb := 2.02222 * v_max_total_mb + 56441.6;
            IF dg.free_mb > v_required_free_mb THEN v_enuf_free := TRUE; END IF;
         -- Full rack is most conservative, it will be default
         ELSE
            -- Use eqn: y = 2.14077 x+54276.4
            v_required_free_mb := 2.14077 * v_max_total_mb + 54276.4;
            IF dg.free_mb > v_required_free_mb THEN v_enuf_free := TRUE; END IF;

         END IF;

         -- DISK usable file MB
         v_usable_mb := ROUND((dg.free_mb - v_required_free_mb)/2);
         v_disk_desc := 'TWO disks';

         -- CELL usable file MB
         v_one_cell_usable_mb := ROUND( (dg.free_mb - v_one_cell_req_mir_free_mb)/2 );

      END IF;
      DBMS_OUTPUT.PUT('|'||RPAD(dg.name,v_offset-40));
      DBMS_OUTPUT.PUT('|'||RPAD(nvl(dg.type,'  '),v_offset-41));
      DBMS_OUTPUT.PUT('|'||LPAD(TO_CHAR(v_num_disks),v_offset-45));
      DBMS_OUTPUT.PUT('|'||TO_CHAR(v_max_total_mb,'9,999,999'));
      DBMS_OUTPUT.PUT('|'||TO_CHAR(dg.total_mb,'999,999,999'));
      DBMS_OUTPUT.PUT('|'||TO_CHAR(dg.total_mb - dg.free_mb,'999,999,999'));
      DBMS_OUTPUT.PUT('|'||TO_CHAR(dg.free_mb,'999,999,999'));
      DBMS_OUTPUT.PUT('|'||TO_CHAR(ROUND(v_one_cell_req_mir_free_mb),'999,999,999'));
      DBMS_OUTPUT.PUT('|'||TO_CHAR(ROUND(v_required_free_mb),'999,999,999'));
      DBMS_OUTPUT.PUT('|'||TO_CHAR(ROUND(v_usable_mb),'999,999,999'));
      DBMS_OUTPUT.PUT('|'||TO_CHAR(ROUND(v_one_cell_usable_mb),'999,999,999')); 

      IF v_enuf_free THEN
         DBMS_OUTPUT.PUT('|'||'PASS');
      ELSE
         DBMS_OUTPUT.PUT('|'||'FAIL');
      END IF;

     IF dg.type = 'NORMAL' THEN
        -- Calc Free Space for Rebalance Due to Cell Failure
        IF v_req_mirror_free_adj < dg.free_mb THEN
           DBMS_OUTPUT.PUT('|'||'PASS');
        ELSE
            DBMS_OUTPUT.PUT('|'||'FAIL');
            v_cfc_fail_msg := 'Enough Free Space to Rebalance after loss of ONE cell: WARNING (However, cell failure is very rare)';
        END IF;
     ELSE
        -- Calc Free Space for Rebalance Due to Single Cell Failure
        IF v_one_cell_req_mir_free_mb < dg.free_mb THEN
           DBMS_OUTPUT.PUT('|'||'PASS');
        ELSE
           DBMS_OUTPUT.PUT('|'||'FAIL');
           v_cfc_fail_msg := 'Enough Free Space to Rebalance after loss of ONE cell: WARNING (However, cell failure is very rare and high redundancy offers ample protection already)';
        END IF;

     END IF;

     -- Calc Disk Utilization Percentage
        IF dg.total_mb > 0 THEN
           DBMS_OUTPUT.PUT_LINE('|'||TO_CHAR((((dg.total_mb - dg.free_mb)/dg.total_mb)*100),'999.9')||CHR(37)||'|');
        ELSE
           DBMS_OUTPUT.PUT_LINE('|       |');
        END IF;

   END LOOP;

     DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------------------------------------------------------------------');
   <<the_end>>

   IF v_cfc_fail_msg is not null THEN
      DBMS_OUTPUT.PUT_LINE('Cell Failure Coverage Freespace Failures Detected. Warning Message Follows.');
      DBMS_OUTPUT.PUT_LINE(v_cfc_fail_msg);
   END IF;

   DBMS_OUTPUT.PUT_LINE('.  .  .');
   DBMS_OUTPUT.PUT_LINE('Script completed.');

END;
/
WHENEVER SQLERROR EXIT FAILURE;
clear columns

ttitle left '=== asm info ==='
set linesize 150
set pages 100
col name format a13
col REDUNDANCY format a12
col state format a10
select
GROUP_NUMBER, name,
round((total_mb/decode(type,'NORMAL',2,'HIGH',3,'EXTERN',1))/1024) as "TOTAL_GB",
round(usable_file_mb/1024) as "USABLE_FREE_GB",
round((hot_used_mb+cold_used_mb)/decode(type,'NORMAL',2,'HIGH',3,1)/1024) as "DATA_USE_GB",
round((free_mb/decode(type,'NORMAL',2,'HIGH',3,'EXTERN',1))/1024) as "FREE_GB",
round(required_mirror_free_mb/decode(type,'NORMAL',2,'HIGH',3,1)/1024) as "REQ_FREE_REDUN_GB",
type as "REDUNDANCY",
state,
round(((free_mb/decode(type,'NORMAL',2,'HIGH',3,'EXTERN',1))/(total_mb/decode(type,'NORMAL',2,'HIGH',3,'EXTERN',1)))*100,2) as "%FREE"
from v$asm_diskgroup;

ttitle left "=== asm disk info ==="
set pagesize 1000
col name format a15
col label format a40
select b.NAME,a.label,a.DISK_NUMBER,a.MOUNT_STATUS,a.MODE_STATUS,a.STATE 
from v$asm_disk a, v$asm_diskgroup b
where a.group_number=b.group_number
and b.name in (select name from v$asm_diskgroup)
order by b.name, a.disk_number;
spool off;

exit;
