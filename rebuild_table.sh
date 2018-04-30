# #################################################################
# SCRIPT TO REBUILD A GIVEN TABLE AND IT's INDEXES
#
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	16-06-14	    #   #   # #   # 
# Modified:	17-06-14 Inform the user when DB 
#			 is in Force Logging Mode.
#		16-09-14 Add Search Feature.
#		04-01-16 Added DEGREE OF PARALLELISM calculation
# #################################################################

# ###########
# Description:
# ###########
echo
echo "=============================="
echo "This script gets TABLE Details ..."
echo "=============================="
echo
sleep 1


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"                           #Excluded INSTANCES [Will not get reported offline].

# ###########################
# List Available Databases:
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
          echo
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
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

## If OS is Linux:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
  PARALLEL_DEGREE=`cat /proc/cpuinfo| grep processor|wc -l`
        if [ "${PARALLEL_DEGREE##[0-9]*}" ]
                 then
                  PARALLEL_DEGREE=1
        fi

## If OS is SUN:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
  PARALLEL_DEGREE=`kstat cpu_info|grep core_id|sort -u|wc -l`
        if [ -z "${PARALLEL_DEGREE##[0-9]*}" ]
                 then
                  PARALLEL_DEGREE=1
        fi
fi

## If oratab is not exist, or ORACLE_SID not added to oratab, find ORACLE_HOME in user's profile:
if [ -z "${ORACLE_HOME}" ]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash* $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
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

# ########################################
# SQLPLUS: TABLE REBUILD:
# ########################################
# Checking FORCE LOGGING mode:
# ###########################
VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
select force_logging from v\$database;
EOF
)
VAL2=`echo $VAL1| awk '{print $NF}'`
                        case ${VAL2} in
                        YES) echo
                             echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
                             echo "INFO: THE DATABASE IS IN FORCE LOGGING MODE."
                             echo "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
                             echo;sleep 2;;
                        *);;
                        esac

echo "********************************************************************************"
echo "It's HIGHLY RECOMMENDED to run this script during DOWNTIME WINDOW,"
echo "To AVOID INTERRUPTING long running queries against the table during the rebuild."
echo "********************************************************************************"

echo
echo "Enter the OWNER of Table:"
echo "========================"
while read OWNER
 do
        case ${OWNER} in
          "")echo
             echo "Enter the OWNER of the Table:"
             echo "============================";;
          *)
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME=upper('$OWNER');
EOF
)
VAL22=`echo $VAL11| awk '{print $NF}'`
                        case ${VAL22} in
                        0) echo;echo "ERROR: USER [${OWNER}] IS NOT EXIST ON DATABASE [$ORACLE_SID] !"
                           echo; echo "Searching For Users Match The Provided String ..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
select username "Users Match Provided String" from dba_users where username like upper ('%$OWNER%');
EOF
             		   echo;echo "Enter A Valid Table Owner:"
             		   echo "=========================";;
                        *) break;;
                        esac
          esac
 done
echo
echo "Enter the TABLE Name:"
echo "===================="
while read OBJECT_NAME
 do
        case ${OBJECT_NAME} in
          "")echo
             echo "Enter the TABLE NAME:"
             echo "====================";;
          *)
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_TABLES WHERE OWNER=upper('$OWNER') AND TABLE_NAME=UPPER('$OBJECT_NAME');
EOF
)
VAL22=`echo $VAL11| awk '{print $NF}'`
                        case ${VAL22} in
                        0) echo;echo "INFO: TABLE [${OBJECT_NAME}] IS NOT EXIST UNDER SCHEMA [$OWNER] !"
                           echo;echo "Searching for tables match the provided string ..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
select table_name "Tables Match Provided String" from dba_tables where owner=upper('$OWNER') and table_name like upper ('%$OBJECT_NAME%');
EOF
                           echo;echo "Enter A VALID TABLE NAME:"
                           echo "========================";;
                        *) break;;
                        esac
          esac
 done

# INFO AND REBUILD PROCEDURE:
# ##########################
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 100
SPOOL TABLE_${OBJECT_NAME}_INFO_BEFORE_REBUILD.log
PROMPT
PROMPT TABLE INFO:
PROMPT -----------

set linesize 180
col "OWNER.TABLE" for a35
col tablespace_name for a20
col "READONLY" for a8
select t.owner||'.'||t.table_name "OWNER.TABLE",t.TABLESPACE_NAME,t.PCT_FREE
,t.PCT_USED,d.extents,t.MAX_EXTENTS,t.COMPRESSION,t.READ_ONLY "READONLY",o.created,t.LAST_ANALYZED,d.bytes/1024/1024 SIZE_MB
from dba_tables t, dba_objects o, dba_segments d
where t.owner= upper('$OWNER')
and t.table_name = upper('$OBJECT_NAME')
and o.owner=t.owner
and o.object_name=t.table_name
and o.owner=d.owner
and t.table_name=d.SEGMENT_NAME;

PROMPT
PROMPT
PROMPT INDEXES BEFORE REBUILD:
PROMPT ----------------------

set pages 100
set heading on
COLUMN OWNER FORMAT A25 heading "Index Owner"
COLUMN INDEX_NAME FORMAT A30 heading "Index Name"
COLUMN COLUMN_NAME FORMAT A25 heading "On Column"
COLUMN COLUMN_POSITION FORMAT 9999 heading "Pos"
COLUMN "INDEX" FORMAT A35
COLUMN TABLESPACE_NAME FOR A25
COLUMN INDEX_TYPE FOR A26
SELECT IND.OWNER||'.'||IND.INDEX_NAME "INDEX",
       IND.INDEX_TYPE,
       COL.COLUMN_NAME,
       COL.COLUMN_POSITION,
       IND.TABLESPACE_NAME,
       IND.STATUS,
       IND.UNIQUENESS,
       IND.LAST_ANALYZED,d.bytes/1024/1024 SIZE_MB
FROM   SYS.DBA_INDEXES IND,
       SYS.DBA_IND_COLUMNS COL,
       DBA_SEGMENTS d
WHERE  IND.TABLE_NAME = upper('$OBJECT_NAME')
AND    IND.TABLE_OWNER = upper('$OWNER')
AND    IND.TABLE_NAME = COL.TABLE_NAME
AND    IND.OWNER = d.OWNER
AND    IND.OWNER = COL.INDEX_OWNER
AND    IND.TABLE_OWNER = COL.TABLE_OWNER
AND    IND.INDEX_NAME = COL.INDEX_NAME
AND    IND.INDEX_NAME = d.SEGMENT_NAME;

SPOOL OFF
SET FEEDBACK OFF
exec dbms_lock.sleep(5);

PROMPT REBUILDING TABLE PROCEDURE WILL START WITHIN 5 Seconds ...
PROMPT -------------------------------------------------------

exec dbms_lock.sleep(4);
PROMPT [5]
exec dbms_lock.sleep(1);
PROMPT [4]
exec dbms_lock.sleep(1);
PROMPT [3]
exec dbms_lock.sleep(1);
PROMPT [2]
exec dbms_lock.sleep(1);
PROMPT [1]
exec dbms_lock.sleep(1);
PROMPT
PROMPT [REBUILDING] ...
SET FEEDBACK ON

PROMPT
PROMPT SETTING TABLE $OWNER.$OBJECT_NAME IN NOLOGGING MODE ...
ALTER TABLE $OWNER.$OBJECT_NAME NOLOGGING;
PROMPT REBUILDING TABLE $OWNER.$OBJECT_NAME ...
ALTER TABLE $OWNER.$OBJECT_NAME MOVE PARALLEL $PARALLEL_DEGREE;
PROMPT SETTING TABLE $OWNER.$OBJECT_NAME IN LOGGING MODE ...
ALTER TABLE $OWNER.$OBJECT_NAME LOGGING;

SET TERMOUT OFF
set pages 0
SET LINESIZE 157
SET PAGESIZE 5000
SET HEADING OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET ECHO OFF

SPOOL REBUILD_TABLE_${OBJECT_NAME}_SCRIPT.sql
select 'SPOOL REBUILD_TABLE_${OBJECT_NAME}_SCRIPT.log' from dual;
select 'ALTER INDEX '||owner||'."'||index_name||'" REBUILD ONLINE PARALLEL $PARALLEL_DEGREE;' from dba_indexes
where OWNER=upper('$OWNER') and TABLE_NAME=upper('$OBJECT_NAME') and STATUS <> 'VALID';
select 'spool off' from dual;
SPOOL OFF

SET TERMOUT ON ECHO ON FEEDBACK ON VERIFY ON
PROMPT
PROMPT REBUILDING UNUSABLE INDEXES ...
@REBUILD_TABLE_${OBJECT_NAME}_SCRIPT.sql

PROMPT
PROMPT GATHERING STATISTICS ON TABLE [${OWNER}.${OBJECT_NAME}] AND ITS INDEXES ...
PROMPT
BEGIN
DBMS_STATS.GATHER_TABLE_STATS (
ownname => upper('$OWNER'),
tabname => upper('$OBJECT_NAME'),
cascade => TRUE,
METHOD_OPT => 'FOR ALL COLUMNS SIZE SKEWONLY',
DEGREE	=> DBMS_STATS.AUTO_DEGREE,
estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE);
END;
/

set pages 100
SET HEADING ON
SPOOL TABLE_${OBJECT_NAME}_INFO_AFTER_REBUILD.log
PROMPT
PROMPT TABLE INFO:
PROMPT -----------

set linesize 180
col "OWNER.TABLE" for a35
col tablespace_name for a20
col "READONLY" for a8
select t.owner||'.'||t.table_name "OWNER.TABLE",t.TABLESPACE_NAME,t.PCT_FREE
,t.PCT_USED,d.extents,t.MAX_EXTENTS,t.COMPRESSION,t.READ_ONLY "READONLY",o.created,t.LAST_ANALYZED,d.bytes/1024/1024 SIZE_MB
from dba_tables t, dba_objects o, dba_segments d
where t.owner= upper('$OWNER')
and t.table_name = upper('$OBJECT_NAME')
and o.owner=t.owner
and o.object_name=t.table_name
and o.owner=d.owner
and t.table_name=d.SEGMENT_NAME;

PROMPT
PROMPT
PROMPT INDEXES AFTER REBUILD:
PROMPT ----------------------

COLUMN OWNER FORMAT A25 heading "Index Owner"
COLUMN INDEX_NAME FORMAT A30 heading "Index Name"
COLUMN COLUMN_NAME FORMAT A25 heading "On Column"
COLUMN COLUMN_POSITION FORMAT 9999 heading "Pos"
COLUMN "INDEX" FORMAT A35
COLUMN TABLESPACE_NAME FOR A25
COLUMN INDEX_TYPE FOR A26
SELECT IND.OWNER||'.'||IND.INDEX_NAME "INDEX",
       IND.INDEX_TYPE,
       COL.COLUMN_NAME,
       COL.COLUMN_POSITION,
       IND.TABLESPACE_NAME,
       IND.STATUS,
       IND.UNIQUENESS,
       IND.LAST_ANALYZED,d.bytes/1024/1024 SIZE_MB
FROM   SYS.DBA_INDEXES IND,
       SYS.DBA_IND_COLUMNS COL,
       DBA_SEGMENTS d
WHERE  IND.TABLE_NAME = upper('$OBJECT_NAME')
AND    IND.TABLE_OWNER = upper('$OWNER')
AND    IND.TABLE_NAME = COL.TABLE_NAME
AND    IND.OWNER = d.OWNER
AND    IND.OWNER = COL.INDEX_OWNER
AND    IND.TABLE_OWNER = COL.TABLE_OWNER
AND    IND.INDEX_NAME = COL.INDEX_NAME
AND    IND.INDEX_NAME = d.SEGMENT_NAME;

SPOOL OFF

PROMPT
PROMPT ------------------------------------------

PROMPT TABLE [${OBJECT_NAME}] HAS BEEN REBUILT.
PROMPT ------------------------------------------

PROMPT

EOF


# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
