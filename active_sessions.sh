# ###############################################################################
# Script to show all Active Sessions info.	
# [Ver 1.3]					
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	07-02-17	    #   #   # #   # 
# Modified:	03-08-17 Added Running Jobs.
#		08-01-18 Added Kill Command for long running queries.
#
#
#
#
#
#
#
#
#
#
# ##############################################################################
SCRIPT_NAME="active_sessions.sh"

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

# ########################################
# Exit if the user is not the Oracle Owner:
# ########################################
CURR_USER=`whoami`
        if [ ${ORA_USER} != ${CURR_USER} ]; then
          echo ""
          echo "You're Running This Sctipt with User: \"${CURR_USER}\" !!!"
          echo "Please Run This Script With The Right OS User: \"${ORA_USER}\""
          echo "Script Terminated!"
          exit
        fi

# ###################################
# SQLPLUS: Getting All Sessions Info:
# ###################################
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
EXEC DBMS_SESSION.set_identifier('${SCRIPT_NAME}');
set feedback off
prompt
prompt
prompt ================================
prompt ACTIVE Sessions in the Database:
prompt ================================
prompt

set feedback off linesize 168 pages 1000
col inst for 99
col module for a27
col event for a24
col MACHINE for a27
col "ST|WAITD|ACT_SINC|LOGIN" for a40
col "INST|USER|SID,SERIAL#" for a30
col "INS|USER|SID,SER|MACHIN|MODUL" for a69
col "PREV|CURR SQLID" for a27
col "I|BLK_BY" for a9
col "CURRENT SQL|REMIN_SEC" for a21
select
substr(s.INST_ID||'|'||s.USERNAME||'| '||s.sid||','||s.serial#||' |'||substr(s.MACHINE,1,22)||'|'||substr(s.MODULE,1,18),1,69)"INS|USER|SID,SER|MACHIN|MODUL"
--select s.INST_ID||'|'||s.USERNAME||' | '||s.sid||','||s.serial# "INST|USER|SID,SERIAL#"
--,substr(s.MODULE,1,27)"MODULE"
--,substr(s.MACHINE,1,27)"MACHINE"
,substr(s.status||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||to_char(LOGON_TIME,'ddMon HH24:MI'),1,40) "ST|WAITD|ACT_SINC|LOGIN"
,substr(w.event,1,24) "EVENT"
--,s.PREV_SQL_ID||'|'||s.SQL_ID "PREV|CURR SQLID"
,s.SQL_ID||'|'||round(w.TIME_REMAINING_MICRO/1000000) "CURRENT SQL|REMIN_SEC"
,s.FINAL_BLOCKING_INSTANCE||'|'||s.FINAL_BLOCKING_SESSION "I|BLK_BY"
from 	gv\$session s, gv\$session_wait w
where 	s.USERNAME is not null
and 	s.sid=w.sid
and	s.STATUS='ACTIVE'
and	w.EVENT NOT IN ('SQL*Net message from client','class slave wait','Streams AQ: waiting for messages in the queue','Streams capture: waiting for archive log'
	,'Streams AQ: waiting for time management or cleanup tasks','PL/SQL lock timer','rdbms ipc message')
order by "I|BLK_BY" desc,w.event,"INS|USER|SID,SER|MACHIN|MODUL","ST|WAITD|ACT_SINC|LOGIN" desc,"CURRENT SQL|REMIN_SEC";
--order by "ST|WA_ST|WAITD|ACT_SINC|LOG_T" desc, "INST|USER|SID,SERIAL#";
set pages 0
PROMPT
PROMPT SESSIONS STATUS:
PROMPT ----------------

select 'ALL:        '||count(*)	from gv\$session;
select 'BACKGROUND: '||count(*)  from gv\$session where USERNAME is null; 
select 'INACTIVE:   '||count(*) 	from gv\$session where USERNAME is not null and status='INACTIVE';
select 'ACTIVE:     '||count(*) 	from gv\$session where USERNAME is not null and status='ACTIVE';


prompt
prompt =======================
Prompt Running Jobs:
prompt =======================

set pages 1000
col INS                         for 999
col "JOB_NAME|OWNER|SPID|SID"   for a55
col ELAPSED_TIME                for a17
col CPU_USED                    for a17
col "WAIT_SEC"                  for 9999999999
col WAIT_CLASS                  for a15
col "BLKD_BY"                   for 9999999
col "WAITED|WCLASS|EVENT"       for a45
select j.RUNNING_INSTANCE INS,j.JOB_NAME ||' | '|| j.OWNER||' |'||SLAVE_OS_PROCESS_ID||'|'||j.SESSION_ID"JOB_NAME|OWNER|SPID|SID"
,s.FINAL_BLOCKING_SESSION "BLKD_BY",ELAPSED_TIME,CPU_USED
,substr(s.SECONDS_IN_WAIT||'|'||s.WAIT_CLASS||'|'||s.EVENT,1,45) "WAITED|WCLASS|EVENT",S.SQL_ID
from dba_scheduler_running_jobs j, gv\$session s
where   j.RUNNING_INSTANCE=S.INST_ID(+)
and     j.SESSION_ID=S.SID(+)
order by "JOB_NAME|OWNER|SPID|SID",ELAPSED_TIME;

prompt
prompt =======================
Prompt Long Running Operations:
prompt =======================

set linesize 175 pages 1000
col OPERATION                   for a21
col "%DONE"                     for 99.999
col "STARTED|MIN_ELAPSED|REMAIN" for a30
col MESSAGE                     for a77
col "USERNAME| SID,SERIAL#"     for a28
        select USERNAME||'| '||SID||','||SERIAL# "USERNAME| SID,SERIAL#",SQL_ID
        --,OPNAME OPERATION
        ,substr(SOFAR/TOTALWORK*100,1,5) "%DONE"
        ,to_char(START_TIME,'DD-Mon HH24:MI')||'| '||trunc(ELAPSED_SECONDS/60)||'|'||trunc(TIME_REMAINING/60) "STARTED|MIN_ELAPSED|REMAIN" ,MESSAGE
        from v\$session_longops where SOFAR/TOTALWORK*100 <>'100'
        order by "STARTED|MIN_ELAPSED|REMAIN" desc, "USERNAME| SID,SERIAL#";

EOF

ACTIVE_SESS_COUNT_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from v\$session where
username is not null
and module is not null
-- 1 is the number of hours
and last_call_et > 60*60*1
and status = 'ACTIVE';
exit;
EOF
)
ACTIVE_SESS_COUNT=`echo ${ACTIVE_SESS_COUNT_RAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# If ASM DISKS Are Exist, Check the size utilization:
  if [ ${ACTIVE_SESS_COUNT} -gt 0 ]
   then

${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
PROMPT
prompt ============================================================
PROMPT Active Sessions for More Than 1 Hour On Instance [${ORACLE_SID}]:
PROMPT ============================================================

set lines 168
col "MODULE | MACHINE" for a63
col DURATION_HOURS for 99999.9
col STARTED_AT for a13
col "USERNAME| SID,SERIAL#" for a30
col "SQL_ID | SQL_TEXT" for a120
select username||'| '||sid ||','|| serial# "USERNAME| SID,SERIAL#",substr(MODULE,1,30)||' | '||substr(MACHINE,1,30) "MODULE | MACHINE", to_char(sysdate-last_call_et/24/60/60,'DD-MON HH24:MI') STARTED_AT,
last_call_et/60/60 "DURATION_HOURS"
--,SQL_ID ||' | '|| (select SQL_FULLTEXT from v\$sql where address=sql_address) "SQL_ID | SQL_TEXT"
,SQL_ID
from v\$session where
username is not null
and module is not null
-- 1 is the number of hours
and last_call_et > 60*60*1
and status = 'ACTIVE'
order by "DURATION_HOURS";

set pages 0 echo off feedback off linesize 168
PROMPT
PROMPT Providing Kill Command for Active Sessions since more than 1 Hour: [Don't kill unless you investigate these sessions first ;-)]
PROMPT ------------------------------------------------------------------

select 'ALTER SYSTEM DISCONNECT SESSION '''||sid ||','|| serial#||''' IMMEDIATE;'from v\$session where
username is not null
and module is not null
-- 1 is the number of hours
and last_call_et > 60*60*1
and status = 'ACTIVE'
order by last_call_et/60/60;

PROMPT

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
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
