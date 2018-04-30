# #######################################################################################
# Retrieve the SQLTEXT + BIND VARIABLES + EXEC PLAN
VER="[1.5]"
# 				  	#   #     #
# Authors:	Mahmmoud ADEL	       # # # #   # #
# 		Farrukh Salman	      #  #   #  ####
# Created:	24-12-11	     #   #   # #    # 
# Modified:	31-12-13	     
#		Customized the script to run on
#		various environments.
#		06-05-14 Getting the Bind Variable info for the SQLID
#		05-11-15 Fix Divided by Zero error
#		16-06-16 Added SQL Tuning Option
#		26-02-17 Added Execution History quoted from sqlhistory.sql written by: 
#			 Tim Gorman (Evergreen Database Technologies, Inc.)
#		14-11-17 Added a check for available tuning tasks
#
#
# #######################################################################################

# ###########
# Description:
# ###########
echo
echo "====================================================================================================="
echo "This script shows SQLTEXT + BIND VARIABLES + EXEC PLAN for SQLID And provide the option to Tune it..."
echo "====================================================================================================="
echo
sleep 1

ORACLE_OWNER_VFY="N"
SKIPDBS="ASM\|MGMTDB"

# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"                           #Excluded INSTANCES [Will not get reported offline].

# ###########################
# Listing Available Databases:
# ###########################

# Count Instance Numbers:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )

# Exit if No DBs are running:
if [ $INS_COUNT -eq 0 ]
 then
   echo No Database Running !
   exit
fi

# If there is ONLY one DB set it as default without prompt for selection:
if [ $INS_COUNT -eq 1 ]
 then
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|grep -v ${SKIPDBS}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# If there is more than one DB ASK the user to select:
elif [ $INS_COUNT -gt 1 ]
 then
    echo
    echo "Select the ORACLE_SID:[Enter the number]"
    echo ---------------------
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|grep -v ${SKIPDBS}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
        if [ -z "${REPLY##[0-9]*}" ]
         then
          export ORACLE_SID=$DB_ID
	  echo
          echo Selected Instance:
          echo "********"
          echo $DB_ID
          echo "********"
	  echo
          break
         else
          export ORACLE_SID=${REPLY}
          break
        fi
     done

fi
# Exit if the user selected a Non Listed Number:
        if [ -z "${ORACLE_SID}" ]
         then
          echo "You've Entered An INVALID ORACLE_SID"
          exit
        fi

# #########################
# Getting ORACLE_HOME
# #########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|grep -v ASM|grep -v "\-MGMTDB"|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

# SETTING ORATAB:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  export ORATAB
## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  export ORATAB
fi

# ATTEMPT1: Get ORACLE_HOME using pwdx command:
  PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
  export PMON_PID
  ORACLE_HOME=`pwdx ${PMON_PID}|awk '{print $NF}'|sed -e 's/\/dbs//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from PWDX is ${ORACLE_HOME}"

# ATTEMPT2: If ORACLE_HOME not found get it from oratab file:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## If OS is Linux:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
fi
#echo "ORACLE_HOME from oratab is ${ORACLE_HOME}"
fi

# ATTEMPT3: If ORACLE_HOME is still not found, search for the environment variable: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from environment  is ${ORACLE_HOME}"
fi

# ATTEMPT4: If ORACLE_HOME is not found in the environment search user's profile: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash_profile $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
#echo "ORACLE_HOME from User Profile is ${ORACLE_HOME}"
fi

# ATTEMPT5: If ORACLE_HOME is still not found, search for orapipe: [Least accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from orapipe search is ${ORACLE_HOME}"
fi

# TERMINATE: If all above attempts failed to get ORACLE_HOME location, EXIT the script:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  echo "Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory in order to get this script to run properly"
  echo "e.g."
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
exit
fi

# ########################################
# Exit if the user is not the Oracle Owner:
# ########################################
                case ${ORACLE_OWNER_VFY} in
                "Y")
CURR_USER=`whoami`
        if [ ${ORA_USER} != ${CURR_USER} ]; then
          echo ""
          echo "You're Running This Sctipt with User: \"${CURR_USER}\" !!!"
          echo "Please Run This Script With The Right OS User: \"${ORA_USER}\""
          echo "Script Terminated!"
          exit
        fi;;
                esac

# ########################################
# SQLPLUS: Check SQL FULLTEXT & EXEC PLAN:
# ########################################
# Variables
echo 
echo "Enter the SQL_ID:"
echo "================"
while read SQLID
do

VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set feedback off
SELECT COUNT(*) FROM V\$SQL WHERE SQL_ID='$SQLID';
EOF
)
VAL2=`echo ${VAL1}| awk '{print $NF}'`

                        if [ ${VAL2} -gt 0 ]
                         then

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set feedback off
set linesize 180
col SQL_FULLTEXT for a140

PROMPT
PROMPT *************************
PROMPT Statement Info:
PROMPT *************************
SET LONG 999999999 PAGESIZE 10000 LINESIZE 200
col "ELAPSED|CPU TIME/EXC_SEC" for a24
col "PLSQL|JAVA TIME/EXEC_SEC" for a27
col "APP|USR_IO|CLS WAIT_T/EXEC_SEC" for a30
col "BUFF_GET|DISK_R|DIRECT_W/EXC" for a29
col MODULE for a15
VARIABLE A REFCURSOR;
DECLARE
l_cursor SYS_REFCURSOR;
BEGIN

open :A for

select executions,round((ELAPSED_TIME/executions)/1000000,2)||' | '||round((CPU_TIME/executions)/1000000,2) "ELAPSED|CPU TIME/EXC_SEC",
round((APPLICATION_WAIT_TIME/executions)/1000000,2)||' | '||round((USER_IO_WAIT_TIME/executions)/1000000,2)||' | '||round((CLUSTER_WAIT_TIME/executions)/1000000,2)
"APP|USR_IO|CLS WAIT_T/EXEC_SEC",
round((PLSQL_EXEC_TIME/executions)/1000000,2)||' | '||round((JAVA_EXEC_TIME/executions)/1000000,2) "PLSQL|JAVA TIME/EXEC_SEC",
round((ROWS_PROCESSED/executions),1) "ROWS_PROCESSED/EXEC",
round((BUFFER_GETS/executions),2)||' | '||round((DISK_READS/executions),2)||' | '||round((DIRECT_WRITES/executions),2) "BUFF_GET|DISK_R|DIRECT_W/EXC",
round(PERSISTENT_MEM/1024/1024,2) "P_MEM_MB", USERS_EXECUTING,substr(MODULE,1,15)"MODULE", FIRST_LOAD_TIME, LAST_LOAD_TIME
from v\$sql where SQL_ID='$SQLID';

END;
/
PRINT A;
/

PROMPT
PROMPT *************************
PROMPT BIND VARIABLES + SQL TEXT:
PROMPT *************************
set heading off
SET LONG 999999999 PAGESIZE 10000 LINESIZE 200
select 'VARIABLE '||trim (leading ':' from name)||' '||case when datatype_string= 'DATE' then 'VARCHAR2(60)' else datatype_string end||';' from v\$sql_bind_capture
where SQL_ID='$SQLID' and CHILD_NUMBER = (select max(CHILD_NUMBER) from v\$sql_bind_capture where SQL_ID='$SQLID');
select 'EXECUTE '||name||' := '||''''||value_string||''''||';' from v\$sql_bind_capture
where SQL_ID='$SQLID' and CHILD_NUMBER = (select max(CHILD_NUMBER) from v\$sql_bind_capture where SQL_ID='$SQLID');
select sql_fulltext from v\$sql where sql_id='$SQLID' and CHILD_NUMBER = (select max(CHILD_NUMBER) from v\$sql where SQL_ID='$SQLID');
set heading on

PROMPT
set heading off
select 'Notes: (11g Onwards)' from dual;
PROMPT -------

select
decode(IS_BIND_SENSITIVE,'Y','- The Bind Variables for this statement are Being CHANGED.','N','- The Bind Variables for this statement have NEVER CHANGED.'),
decode(IS_BIND_AWARE,'Y','- Adaptive Cursor Sharing CHANGED the initial execution plan for that SQL_ID at least one time.','N',''),
'  Child Number: '||CHILD_NUMBER
from v\$sql where sql_id='$SQLID' and CHILD_NUMBER = (select max(CHILD_NUMBER) from v\$sql where SQL_ID='$SQLID');
set heading on

/*
PROMPT
PROMPT
PROMPT *********************
PROMPT BIND VARIABLE VALUES:
PROMPT *********************

col BIND_VARIABLE for a20
col VALUE for a100
col DATATYPE for a20
select name BIND_VARIABLE,value_string VALUE,datatype_string DATATYPE from v\$sql_bind_capture
where SQL_ID='$SQLID' and CHILD_NUMBER = (select max(CHILD_NUMBER) from v\$sql_bind_capture where SQL_ID='$SQLID');

PROMPT
PROMPT
PROMPT *********************
PROMPT EXECUTION PLAN:
PROMPT *********************

col PLAN_TABLE_OUTPUT for a156
SELECT * FROM table(DBMS_XPLAN.DISPLAY_CURSOR(('$SQLID')));
*/

PROMPT
PROMPT
PROMPT ***********************
PROMPT EXECUTION PLAN History: Written By: Tim Gorman (Evergreen Database Technologies, Inc.)
PROMPT ***********************
/**********************************************************************
 * File:        sqlhistory.sql
 * Type:        SQL*Plus script
 * Author:      Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:        29sep08
 *
 * Description:
 *	SQL*Plus script to query the "history" of a specified SQL
 *	statement, using its "SQL ID" across all database instances
 *	in a database, using the AWR repository.  This report is useful
 *	for obtaining an hourly perspective on SQL statements seen in
 *	more aggregated reports.
 *
 * Modifications:
 *	TGorman	29sep08	adapted from the earlier STATSPACK-based
 *			"sphistory.sql" script
 *********************************************************************/
set echo off
set feedback off timing off verify off pagesize 200 linesize 200 recsep off echo off
set serveroutput on size 1000000
col phv heading "Plan|Hash Value"
col snap_time format a12 truncate heading "Snapshot|Time"
col execs format 999,999,990 heading "Execs"
col lio_per_exec format 999,999,999,990.00 heading "Avg Logical IO|Per Exec"
col pio_per_exec format 999,999,999,990.00 heading "Avg Physical IO|Per Exec"
col cpu_per_exec format 999,999,999,990.00 heading "Avg|CPU (secs)|Per Exec"
col ela_per_exec format 999,999,999,990.00 heading "Avg|Elapsed (secs)|Per Exec"
col sql_text format a64 heading "Text of SQL statement"
clear breaks computes
ttitle off
btitle off

variable v_nbr_days number


declare
	cursor get_phv(in_sql_id in varchar2, in_days in integer)
	is
	select	ss.plan_hash_value,
		min(s.begin_interval_time) min_time,
		max(s.begin_interval_time) max_time,
		min(s.snap_id) min_snap,
		max(s.snap_id) max_snap,
		sum(ss.executions_delta) sum_execs,
		sum(ss.disk_reads_delta) sum_disk_reads,
		sum(ss.buffer_gets_delta) sum_buffer_gets,
		sum(ss.cpu_time_delta)/1000000 sum_cpu_time,
		sum(ss.elapsed_time_delta)/1000000 sum_elapsed_time
	from	dba_hist_sqlstat	ss,
		dba_hist_snapshot	s
	where	ss.dbid = s.dbid
	and	ss.instance_number = s.instance_number
	and	ss.snap_id = s.snap_id
	and	ss.sql_id = in_sql_id
	/* and	ss.executions_delta > 0 */
	and	s.begin_interval_time >= sysdate-in_days
	group by ss.plan_hash_value
	order by sum_elapsed_time desc;
        --
	cursor get_xplan(in_sql_id in varchar2, in_phv in number)
	is
	select	plan_table_output
	from	table(dbms_xplan.display_awr(in_sql_id, in_phv, null, 'ALL -ALIAS'));
	--
	v_prev_plan_hash_value	number := -1;
	v_text_lines		number := 0;
	v_errcontext		varchar2(100);
	v_errmsg		varchar2(100);
	v_display_sql_text	boolean;
	--
begin
	--
	v_errcontext := 'query NBR_DAYS from DUAL';
	select	decode('100','',10,to_number(nvl('100','10')))
	into	:v_nbr_days
	from	dual;
	--
	v_errcontext := 'open/fetch get_phv';
	for phv in get_phv('${SQLID}', :v_nbr_days) loop
		--
		if get_phv%rowcount = 1 then
			--
			dbms_output.put_line('+'||
				rpad('-',12,'-')||
				rpad('-',10,'-')||
				rpad('-',10,'-')||
				rpad('-',12,'-')||
				rpad('-',15,'-')||
				rpad('-',15,'-')||
				rpad('-',12,'-')||
				rpad('-',12,'-')||'+');
			dbms_output.put_line('|'||
				rpad('Plan HV',12,' ')||
				rpad('Min Snap',10,' ')||
				rpad('Max Snap',10,' ')||
				rpad('Execs',12,' ')||
				rpad('LIO',15,' ')||
				rpad('PIO',15,' ')||
				rpad('CPU',12,' ')||
				rpad('Elapsed',12,' ')||'|');
			dbms_output.put_line('+'||
				rpad('-',12,'-')||
				rpad('-',10,'-')||
				rpad('-',10,'-')||
				rpad('-',12,'-')||
				rpad('-',15,'-')||
				rpad('-',15,'-')||
				rpad('-',12,'-')||
				rpad('-',12,'-')||'+');
			--
		end if;
		--
		dbms_output.put_line('|'||
			rpad(trim(to_char(phv.plan_hash_value)),12,' ')||
			rpad(trim(to_char(phv.min_snap)),10,' ')||
			rpad(trim(to_char(phv.max_snap)),10,' ')||
			rpad(trim(to_char(phv.sum_execs,'999,999,990')),12,' ')||
			rpad(trim(to_char(phv.sum_buffer_gets,'999,999,999,990')),15,' ')||
			rpad(trim(to_char(phv.sum_disk_reads,'999,999,999,990')),15,' ')||
			rpad(trim(to_char(phv.sum_cpu_time,'999,990.00')),12,' ')||
			rpad(trim(to_char(phv.sum_elapsed_time,'999,990.00')),12,' ')||'|');
		--
		v_errcontext := 'fetch/close get_phv';
		--
	end loop;
	dbms_output.put_line('+'||
		rpad('-',12,'-')||
		rpad('-',10,'-')||
		rpad('-',10,'-')||
		rpad('-',12,'-')||
		rpad('-',15,'-')||
		rpad('-',15,'-')||
		rpad('-',12,'-')||
		rpad('-',12,'-')||'+');
	--
	v_errcontext := 'open/fetch get_phv';
	for phv in get_phv('${SQLID}', :v_nbr_days) loop
		--
		if v_prev_plan_hash_value <> phv.plan_hash_value then
			--
			v_prev_plan_hash_value := phv.plan_hash_value;
			v_display_sql_text := FALSE;
			--
			v_text_lines := 0;
			v_errcontext := 'open/fetch get_xplan';
			for s in get_xplan('${SQLID}', phv.plan_hash_value) loop
				--
				if v_text_lines = 0 then
					dbms_output.put_line('.');
					dbms_output.put_line('========== PHV = ' ||
						phv.plan_hash_value ||
						'==========');
					dbms_output.put_line('First seen from "'||
						to_char(phv.min_time,'MM/DD/YY HH24:MI:SS') ||
						'" (snap #'||phv.min_snap||')');
					dbms_output.put_line('Last seen from  "'||
						to_char(phv.max_time,'MM/DD/YY HH24:MI:SS') ||
						'" (snap #'||phv.max_snap||')');
					dbms_output.put_line('.');
					dbms_output.put_line(
						rpad('Execs',15,' ')||
						rpad('LIO',15,' ')||
						rpad('PIO',15,' ')||
						rpad('CPU',15,' ')||
						rpad('Elapsed',15,' '));
					dbms_output.put_line(
						rpad('=====',15,' ')||
						rpad('===',15,' ')||
						rpad('===',15,' ')||
						rpad('===',15,' ')||
						rpad('=======',15,' '));
					dbms_output.put_line(
						rpad(trim(to_char(phv.sum_execs,'999,999,999,990')),15,' ')||
						rpad(trim(to_char(phv.sum_buffer_gets,'999,999,999,990')),15,' ')||
						rpad(trim(to_char(phv.sum_disk_reads,'999,999,999,990')),15,' ')||
						rpad(trim(to_char(phv.sum_cpu_time,'999,999,990.00')),15,' ')||
						rpad(trim(to_char(phv.sum_elapsed_time,'999,999,990.00')),15,' '));
					dbms_output.put_line('.');
				end if;
				--
				if v_display_sql_text = FALSE and
				   s.plan_table_output like 'Plan hash value: %' then
					--
					v_display_sql_text := TRUE;
					--
				end if;
				--
				if v_display_sql_text = TRUE then
					--
					dbms_output.put_line(s.plan_table_output);
					--
				end if;
				--
				v_text_lines := v_text_lines + 1;
				--
			end loop;
			--
		end if;
		--
		v_errcontext := 'fetch/close get_phv';
		--
	end loop;
	--
exception
	when others then
		v_errmsg := sqlerrm;
		raise_application_error(-20000, v_errcontext || ': ' || v_errmsg);
end;
/

break on report
compute sum of execs on report
compute avg of lio_per_exec on report
compute avg of pio_per_exec on report
compute avg of cpu_per_exec on report
compute avg of ela_per_exec on report
ttitle center 'Summary Execution Statistics Over Time'
select	to_char(s.begin_interval_time, 'DD-MON HH24:MI') snap_time,
	ss.executions_delta execs,
	ss.buffer_gets_delta/decode(ss.executions_delta,0,1,ss.executions_delta) lio_per_exec,
	ss.disk_reads_delta/decode(ss.executions_delta,0,1,ss.executions_delta) pio_per_exec,
	(ss.cpu_time_delta/1000000)/decode(ss.executions_delta,0,1,ss.executions_delta) cpu_per_exec,
	(ss.elapsed_time_delta/1000000)/decode(ss.executions_delta,0,1,ss.executions_delta) ela_per_exec
from 	dba_hist_snapshot	s,
	dba_hist_sqlstat	ss
where	ss.dbid = s.dbid
and	ss.instance_number = s.instance_number
and	ss.snap_id = s.snap_id
and	ss.sql_id = '${SQLID}'
/* and	ss.executions_delta > 0 */
and	s.begin_interval_time >= sysdate - :v_nbr_days
order by s.snap_id;
clear breaks computes

set verify on echo on feedback on
ttitle off

EOF

VAL_TUN_TASK_RAW=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_ADVISOR_TASKS where TASK_NAME='${SQLID}_Tuning_Task';
EOF
)
VAL_TUN_TASK=`echo ${VAL_TUN_TASK_RAW}| awk '{print $NF}'`
                        case ${VAL_TUN_TASK} in
                        1) echo
			   echo "-----------------------------------------------------------------------------------------------"
			   echo -e "\033[33;5mA Tuning Task already been found for SQLID [${SQLID}] You can view this task result using:\033[0m"
			   echo "-----------------------------------------------------------------------------------------------"
			   echo "SET LONG 2000000000 pages 10000 lines 200"
			   echo "SELECT DBMS_SQLTUNE.report_tuning_task('${SQLID}_Tuning_Task') AS recommendations FROM dual;";;
                        esac

echo ""
echo "Do you want to Tune This statement Using SQL Tuning Advisor? (NO/YES) Default is [NO]"
echo "============================================================"
while read ANS1
	do
        case ${ANS1} in
        ""|n|N|no|NO|No) break ;;
        ""|y|Y|yes|YES|Yes) 

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
--PROMPT
--PROMPT SQL Statement Full Text:
--PROMPT -----------------------

--SET LONG 2000000000 PAGESIZE 10000 LINESIZE 200
--col SQL_FULLTEXT for a200
--select SQL_FULLTEXT from V\$SQL where SQL_ID='$SQLID';

PROMPT
PROMPT Creating SQL Tuning Task: "${SQLID}_Tuning_Task" ...
DECLARE
   l_sql_tune_task_id  VARCHAR2(100);
   BEGIN
   l_sql_tune_task_id := DBMS_SQLTUNE.create_tuning_task (
             sql_id      => '${SQLID}',
             scope       => DBMS_SQLTUNE.scope_comprehensive,
             time_limit  => 3600,
             task_name   => '${SQLID}_Tuning_Task',
             description => 'Tuning task for statement ${SQLID}');
   DBMS_OUTPUT.put_line('l_sql_tune_task_id: ' || l_sql_tune_task_id);
   END;
   /

PROMPT Executing TUNING Task: "${SQLID}_Tuning_Task" ...
PROMPT
PROMPT Please Wait! This May Take Several Minutes ...
EXEC DBMS_SQLTUNE.execute_tuning_task(task_name => '${SQLID}_Tuning_Task');

PROMPT 
PROMPT SQL Tuning Recommendations:
PROMPT --------------------------

spool ${SQLID}_Tuning_Task_details.log
SET LONG 999999999 PAGESIZE 10000 LINESIZE 200
SELECT DBMS_SQLTUNE.report_tuning_task('${SQLID}_Tuning_Task') AS recommendations FROM dual;

PROMPT
PROMPT For Dropping Tuning Task "${SQLID}_Tuning_Task" Use this SQL command:
PROMPT ------------------------

PROMPT EXEC dbms_sqltune.drop_tuning_task(task_name => '${SQLID}_Tuning_Task');
PROMPT
spool off

EOF
break ;;
        *) echo "Please enter a VALID answer [N|Y]" ;;
        esac
        done

	break
			else
			echo
			echo "<<< The Provided SQLID is NOT found in v\$SQL view! >>>"
			echo 
			echo "Please Enter a Valid SQLID:"
			echo "---------------------------"
			fi
done
# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
