# #################################################
# Script to Check Scheduled Jobs.	#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	02-02-10	    #   #   # #   # 
# Modified:	31-12-13	     
#		Customized the script to run on
#		various environments.
#		14-05-14 Add AUTOTASK MAINT WINDO
#		29-11-15 Add Last Run Details
#
# #################################################
SCRIPT_NAME="db_jobs"
# ###########
# Description:
# ###########
echo
echo "=============================================="
echo "This script Checks ALL database Scheduled Jobs ..."
echo "=============================================="
echo
sleep 1


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"                           #Excluded INSTANCES [Will not get reported offline].


# ##############################
# SCRIPT ENGINE STARTS FROM HERE ............................................
# ##############################

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
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# If there is more than one DB ASK the user to select:
elif [ $INS_COUNT -gt 1 ]
 then
    echo
    echo "Select the ORACLE_SID:[Enter the number]"
    echo ---------------------
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
        if [ -z "${REPLY##[0-9]*}" ]
         then
          export ORACLE_SID=$DB_ID
          echo Selected Instance:
          echo $DB_ID
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
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|grep -v "\-MGMTDB"|awk '{print $1}'|tail -1`
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

# Neutralize login.sql file:
# #########################
# Existance of login.sql file under current working directory eliminates many functions during the execution of this script:

        if [ -f ./login.sql ]
         then
mv ./login.sql   ./login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# ###############################
# SQLPLUS: Check Scheduled Jobs:
# ###############################
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 200
set pages 1000
PROMPT DBMS_JOBS:
PROMPT -----------

col LAST_RUN for a25
col NEXT_RUN for a25
select job,schema_user,failures,to_char(LAST_DATE,'DD-Mon-YYYY hh24:mi:ss')LAST_RUN,to_char(NEXT_DATE,'DD-Mon-YYYY hh24:mi:ss')NEXT_RUN from dba_jobs;

PROMPT 
PROMPT DBMS_SCHEDULER:
PROMPT ----------------

col OWNER for a16
col STATE for a9
col FAILURE_COUNT for 9999 heading 'Fail'
col "DURATION(d:hh:mm:ss)" for a10
col REPEAT_INTERVAL for a40
col LAST_RUN for a20
col NEXT_RUN for a20
--col LAST_START_DATE for a40
--select JOB_NAME,OWNER,ENABLED,STATE,FAILURE_COUNT,to_char(LAST_START_DATE,'DD-Mon-YYYY hh24:mi:ss')LAST_RUN,to_char(NEXT_RUN_DATE,'DD-Mon-YYYY hh24:mi:ss')NEXT_RUN,REPEAT_INTERVAL,
select JOB_NAME,OWNER,ENABLED,STATE,FAILURE_COUNT,to_char(LAST_START_DATE,'DD-Mon-YYYY hh24:mi:ss TZR')LAST_RUN,to_char(NEXT_RUN_DATE,'DD-Mon-YYYY hh24:mi:ss TZR')NEXT_RUN,REPEAT_INTERVAL,
extract(day from last_run_duration) ||':'||
lpad(extract(hour from last_run_duration),2,'0')||':'||
lpad(extract(minute from last_run_duration),2,'0')||':'||
lpad(round(extract(second from last_run_duration)),2,'0') "DURATION(d:hh:mm:ss)"
from dba_scheduler_jobs order by ENABLED,STATE;

PROMPT
PROMPT AUTOTASK INTERNAL MAINTENANCE WINDOWS:
PROMPT ---------------------------------------

col WINDOW_NAME for a17
col NEXT_RUN for a20
col ACTIVE for a6
col OPTIMIZER_STATS for a15
col SEGMENT_ADVISOR for a15
col SQL_TUNE_ADVISOR for a16
col HEALTH_MONITOR for a15
SELECT WINDOW_NAME,TO_CHAR(WINDOW_NEXT_TIME,'DD-MM-YYYY HH24:MI:SS') NEXT_RUN,AUTOTASK_STATUS STATUS,WINDOW_ACTIVE ACTIVE,OPTIMIZER_STATS,SEGMENT_ADVISOR,SQL_TUNE_ADVISOR,HEALTH_MONITOR FROM DBA_AUTOTASK_WINDOW_CLIENTS;

PROMPT
PROMPT FAILED JOBS IN THE LAST 24H:
PROMPT ----------------------------

col LOG_DATE for a36
col OWNER for a15
col JOB_NAME for a35
col STATUS for a11
col RUN_DURATION for a20
select JOB_NAME,OWNER,LOG_DATE,STATUS,ERROR#,RUN_DURATION from DBA_SCHEDULER_JOB_RUN_DETAILS where STATUS='FAILED' and LOG_DATE > sysdate-1 order by JOB_NAME,LOG_DATE;

PROMPT RUNNING JOBS DETAILS:
PROMPT ---------------------

col INS for 999
col "JOB_NAME|OWNER|SPID|SID" for a55
col ELAPSED_TIME for a17
col CPU_USED for a17
col "WAIT_SEC"  for 9999999999
col WAIT_CLASS for a15
col "BLKD_BY" for 9999999
col "WAITED|WCLASS|EVENT"       for a45
select j.RUNNING_INSTANCE INS,j.JOB_NAME ||' | '|| j.OWNER||' |'||SLAVE_OS_PROCESS_ID||'|'||j.SESSION_ID"JOB_NAME|OWNER|SPID|SID"
,s.FINAL_BLOCKING_SESSION "BLKD_BY",ELAPSED_TIME,CPU_USED
,substr(s.SECONDS_IN_WAIT||'|'||s.WAIT_CLASS||'|'||s.EVENT,1,45) "WAITED|WCLASS|EVENT",S.SQL_ID
from dba_scheduler_running_jobs j, gv\$session s
where   j.RUNNING_INSTANCE=S.INST_ID(+)
and     j.SESSION_ID=S.SID(+)
order by "JOB_NAME|OWNER|SPID|SID",ELAPSED_TIME;

EOF

echo "Enter the JOB_NAME/ID to get its details:"
echo "========================================="
read JOB_NAME
# Exit if No Input:
	if [ -z "${JOB_NAME}" ]
	 then
# De-Neutralize login.sql file:
# ############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ./login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ./login.sql_NeutralizedBy${SCRIPT_NAME}  ./login.sql
        fi

	  exit
	fi

# Check if the variable is Number query DBMS_JOBS:
	if [ -z "${JOB_NAME##[0-9]*}" ]
	 then
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
col what for a157
Select what from dba_jobs where job='$JOB_NAME';
EOF

# If variable is Characters query dba_scheduler_jobs:

	else

JOB_OWNER_TMP=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 feedback off;
col what for a157
prompt
select * from (Select owner from dba_scheduler_jobs where job_name='${JOB_NAME}') where rownum=1;
EOF
)

JOB_OWNER=`echo ${JOB_OWNER_TMP}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`
export JOB_OWNER

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 200 pages 1000
col OWNER for a10
col STATE for a11
col FAILURE_COUNT for 999 heading 'Fail'
col "DURATION(d:hh:mm:ss)" for a22
col REPEAT_INTERVAL for a60
--col LAST_START_DATE for a40
col NEXT_RUN for a21
col "STICK|INST" for a10
select JOB_NAME,OWNER,ENABLED,STATE,FAILURE_COUNT,to_char(LAST_START_DATE,'DD-Mon-YYYY hh24:mi:ss')LAST_RUN,REPEAT_INTERVAL,to_char(NEXT_RUN_DATE,'DD-Mon-YYYY hh24:mi:ss')NEXT_RUN,
extract(day from last_run_duration) ||':'||
lpad(extract(hour from last_run_duration),2,'0')||':'||
lpad(extract(minute from last_run_duration),2,'0')||':'||
lpad(round(extract(second from last_run_duration)),2,'0') "DURATION(d:hh:mm:ss)"
,INSTANCE_STICKINESS||'|'||INSTANCE_ID "STICK|INST"
from dba_scheduler_jobs
where JOB_NAME='$JOB_NAME';
prompt Last Run Details:
prompt -----------------

col END_DATE for a20
col START_DATE for a20
col CPU_USED for a17
col OWNER for a15
col JOB_NAME for a40
col STATUS for a11
col RUN_DURATION for a20
select TO_CHAR(ACTUAL_START_DATE,'DD-MON-YY HH24:MI:SS') START_DATE,TO_CHAR(LOG_DATE,'DD-MON-YY HH24:MI:SS') END_DATE,RUN_DURATION,OWNER,JOB_NAME,STATUS,ERROR#,CPU_USED from DBA_SCHEDULER_JOB_RUN_DETAILS where JOB_NAME='$JOB_NAME' and LOG_DATE > sysdate-10 order by LOG_DATE;

prompt
prompt Job Action:
prompt -----------

set long 9999999
col JOB_DDL for a200
col "EXECUTED_PROGRAM | JOB_ACTION" for a40

Select COMMENTS,PROGRAM_OWNER||'.'||PROGRAM_NAME||' | '||JOB_ACTION "EXECUTED_PROGRAM | JOB_ACTION" from dba_scheduler_jobs where JOB_NAME='$JOB_NAME';
select dbms_metadata.get_ddl('PROCOBJ', '${JOB_NAME}','${JOB_OWNER}') JOB_DDL from dual;

EOF
	fi

# De-Neutralize login.sql file:
# ############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ./login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ./login.sql_NeutralizedBy${SCRIPT_NAME}  ./login.sql
        fi

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
