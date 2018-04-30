####################################################
# Script to Check the BLOCKING Locks on the DB.
# Author:       Mahmmoud ADEL        	#   #     #
# Created:      24-05-08 	      # # # #   ###
# Modified:	31-12-13	    #   #   # #   # 
#		Customized the script to run on
#		various environments.
#
####################################################
SCRIPT_NAME="db_locks"
#############
# Description:
#############
echo
echo "==================================================="
echo "This script shows ALL BLOCKING LOCKS on a database."
echo "==================================================="
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
# SQLPLUS: Check BLOCKING Locks:
# ###############################
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF

prompt -------------------------------------------------

prompt List of LOCKED Sessions:
prompt -------------------------------------------------

prompt

set feedback off linesize 220 pages 1000
col module for a27
col event for a24
col MACHINE for a27
col "WA_ST|WAITD|ACT_SINC|LOG_T" for a38
col "INST|USER|SID,SERIAL#" for a30
col "INS|USER|SID,SER|MACHIN|MODUL" for a65
col "PREV|CURR SQLID" for a27
col "I|BLKD_BY" for a12
select
substr(s.INST_ID||'|'||s.USERNAME||'| '||s.sid||','||s.serial#||' |'||substr(s.MACHINE,1,22)||'|'||substr(s.MODULE,1,18),1,65)"INS|USER|SID,SER|MACHIN|MODUL"
--select s.INST_ID||'|'||s.USERNAME||' | '||s.sid||','||s.serial# "INST|USER|SID,SERIAL#"
--,substr(s.MODULE,1,27)"MODULE"
--,substr(s.MACHINE,1,27)"MACHINE"
--,substr(s.status||'|'||w.state||'|'||w.WAIT_TIME_MICRO||'|'||LAST_CALL_ET||'|'||to_char(LOGON_TIME,'ddMon'),1,44) "ST|WA_ST|WAITD|ACT_SINC|LOG_T"
,substr(w.state||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||to_char(LOGON_TIME,'ddMon'),1,38) "WA_ST|WAITD|ACT_SINC|LOG_T"
,substr(w.event,1,24) "EVENT"
--,s.PREV_SQL_ID||'|'||s.SQL_ID "PREV|CURR SQLID"
--,s.SQL_ID "CURRENT SQLID"
,s.FINAL_BLOCKING_INSTANCE||'|'||s.FINAL_BLOCKING_SESSION "I|BLKD_BY"
from    gv\$session s, gv\$session_wait w
where   s.USERNAME is not null
and 	s.FINAL_BLOCKING_SESSION is not null
and     s.sid=w.sid
and     s.STATUS='ACTIVE'
--and     w.EVENT NOT IN ('SQL*Net message from client','class slave wait','Streams AQ: waiting for messages in the queue','Streams capture: waiting for archive log'
--        ,'Streams AQ: waiting for time management or cleanup tasks','PL/SQL lock timer','rdbms ipc message')
order by "I|BLKD_BY" desc,w.event,"INS|USER|SID,SER|MACHIN|MODUL","WA_ST|WAITD|ACT_SINC|LOG_T" desc;

set linesize 160
col BLOCKING_STATUS for a90
select 'User: '||s1.username || '@' || s1.machine || '(SID=' || s1.sid ||' ) running SQL_ID:'||s1.sql_id||'  is blocking
User: '|| s2.username || '@' || s2.machine || '(SID=' || s2.sid || ') running SQL_ID:'||s2.sql_id||' For '||s2.SECONDS_IN_WAIT||' sec
------------------------------------------------------------------------------
Warn user '||s1.username||' Or use the following statement to kill his session:
------------------------------------------------------------------------------
ALTER SYSTEM KILL SESSION '''||s1.sid||','||s1.serial#||''' immediate;' AS blocking_status
from gv\$LOCK l1, gv\$SESSION s1, gv\$LOCK l2, gv\$SESSION s2
 where s1.sid=l1.sid and s2.sid=l2.sid 
 and l1.BLOCK=1 and l2.request > 0
 and l1.id1 = l2.id1
 and l2.id2 = l2.id2 
 order by s2.SECONDS_IN_WAIT desc;

prompt
prompt -------------------------------------------------

Prompt Blocking Locks On Object Level:
prompt -------------------------------------------------

set linesize 1000 pages 100 echo on feedback on
column OS_PID format A15 Heading "OS_PID"
column ORACLE_USER format A15 Heading "ORACLE_USER"
column LOCK_TYPE format A15 Heading "LOCK_TYPE"
column LOCK_HELD format A11 Heading "LOCK_HELD"
column LOCK_REQUESTED format A11 Heading "LOCK_REQUESTED"
column STATUS format A13 Heading "STATUS"
column OWNER format A15 Heading "OWNER"
column OBJECT_NAME format A35 Heading "OBJECT_NAME"
select  l.sid,
        ORACLE_USERNAME oracle_user,
        decode(TYPE,
                'MR', 'Media Recovery',
                'RT', 'Redo Thread',
                'UN', 'User Name',
                'TX', 'Transaction',
                'TM', 'DML',
                'UL', 'PL/SQL User Lock',
                'DX', 'Distributed Xaction',
                'CF', 'Control File',
                'IS', 'Instance State',
                'FS', 'File Set',
                'IR', 'Instance Recovery',
                'ST', 'Disk Space Transaction',
                'TS', 'Temp Segment',
                'IV', 'Library Cache Invalidation',
                'LS', 'Log Start or Switch',
                'RW', 'Row Wait',
                'SQ', 'Sequence Number',
                'TE', 'Extend Table',
                'TT', 'Temp Table', type) lock_type,
        decode(LMODE,
                0, 'None',
                1, 'Null',
                2, 'Row-S (SS)',
                3, 'Row-X (SX)',
                4, 'Share',
                5, 'S/Row-X (SSX)',
                6, 'Exclusive', lmode) lock_held,
        decode(REQUEST,
                0, 'None',
                1, 'Null',
                2, 'Row-S (SS)',
                3, 'Row-X (SX)',
                4, 'Share',
                5, 'S/Row-X (SSX)',
                6, 'Exclusive', request) lock_requested,
        decode(BLOCK,
                0, 'Not Blocking',
                1, 'Blocking',
                2, 'Global', block) status,
        OWNER,
        OBJECT_NAME
from    v\$locked_object lo,        dba_objects do,
        v\$lock l
where   lo.OBJECT_ID = do.OBJECT_ID
AND     l.SID = lo.SESSION_ID
AND l.BLOCK='1';

prompt
prompt -------------------------------------------------

Prompt Long Running Operations:
prompt -------------------------------------------------

set linesize 200 pages 1000
col OPERATION for a21
col "%DONE" for 999.99
col "STARTED|MIN_ELAPSED|REMAIN" for a30
col MESSAGE for a80
col "USERNAME| SID,SERIAL#" for a26
        set linesize 200
        select USERNAME||'| '||SID||','||SERIAL# "USERNAME| SID,SERIAL#",SQL_ID
	--,OPNAME OPERATION
	,SOFAR/TOTALWORK*100 "%DONE"
        ,to_char(START_TIME,'DD-Mon HH24:MI')||'| '||trunc(ELAPSED_SECONDS/60)||'|'||trunc(TIME_REMAINING/60) "STARTED|MIN_ELAPSED|REMAIN" ,MESSAGE
        from v\$session_longops where SOFAR/TOTALWORK*100 <>'100'
        order by "STARTED|MIN_ELAPSED|REMAIN" desc, "USERNAME| SID,SERIAL#";

EOF

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
