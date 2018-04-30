###################################################
# This script show the TABLE DETAILS		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	10-04-11	    #   #   # #   # 
#
###################################################

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
CURR_USER=`whoami`
	if [ ${ORA_USER} != ${CURR_USER} ]; then
	  echo ""
	  echo "You're Running This Sctipt with User: \"${CURR_USER}\" !!!"
	  echo "Please Run This Script With The Right OS User: \"${ORA_USER}\""
	  echo "Script Terminated!"
	  exit
	fi

# ########################################
# SQLPLUS: Get table details:
# ########################################
# Variables
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
                           echo
             		   echo "Enter the OWNER of the Table:"
             		   echo "============================";;
                        *) break;;
                        esac
          esac
 done
echo
echo "Enter the TABLE name:"
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
                        0) echo;echo "ERROR: TABLE [${OBJECT_NAME}] IS NOT EXIST under [${OWNER}] SCHEMA !"
                  	   echo; echo "Searching for tables that match provided string ..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 190
set pagesize 1000
set feedback off
set trim on
set echo off
col TABLE_NAME for a45
select TABLE_NAME FROM DBA_TABLES WHERE OWNER=upper('$OWNER') AND TABLE_NAME like UPPER('%$OBJECT_NAME%');
EOF

                           echo
                           echo "Enter A VALID TABLE NAME:"
                           echo "========================";;
                        *) break;;
                        esac
          esac
 done
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 100
PROMPT
PROMPT General Info:
PROMPT -------------

set linesize 190
col "OWNER.TABLE" for a35
col tablespace_name for a30
col "READONLY" for a8
select t.owner||'.'||t.table_name "OWNER.TABLE",t.TABLESPACE_NAME,t.PCT_FREE
--,t.PCT_USED,d.extents,t.MAX_EXTENTS,t.COMPRESSION,t.READ_ONLY "READONLY",o.created,t.LAST_ANALYZED
,t.PCT_USED,d.extents,t.MAX_EXTENTS,t.COMPRESSION,t.STATUS,o.created,t.LAST_ANALYZED
from dba_tables t, dba_objects o, dba_segments d
where t.owner= upper('$OWNER')
and t.table_name = upper('$OBJECT_NAME')
and o.owner=t.owner
and o.object_name=t.table_name
and o.owner=d.owner
and t.table_name=d.SEGMENT_NAME;

PROMPT
PROMPT Column Details:
PROMPT ---------------

col Name for a30
desc $OWNER.$OBJECT_NAME

PROMPT
PROMPT
PROMPT Getting Table Size [TABLE + ITS LOBS + ITS INDEXES]...
PROMPT -------------------

/*
--select SUM(BYTES/1024/1024)||'MB' FROM SYS.DBA_EXTENTS WHERE  OWNER = upper('$OWNER') AND  SEGMENT_NAME = upper('$OBJECT_NAME') GROUP  BY SEGMENT_NAME;
SELECT TRUNC(sum(bytes)/1024/1024)||' MB'
FROM   (SELECT segment_name table_name, owner, bytes
	FROM dba_segments
	WHERE segment_type = 'TABLE'
	UNION ALL
	SELECT l.table_name, l.owner, s.bytes
	FROM dba_lobs l, dba_segments s
	WHERE s.segment_name = l.segment_name
	AND   s.owner = l.owner
	AND   s.segment_type = 'LOBSEGMENT')
WHERE owner in UPPER('$OWNER')
AND table_name in UPPER('$OBJECT_NAME');
*/
-- The following block quoted from: https://willsnotes.wordpress.com/2013/09/20/find-size-of-table-in-oracle-includes-indexes-and-lobs
set heading on echo off 
COLUMN TABLE_NAME FORMAT A32
COLUMN OBJECT_NAME FORMAT A32
COLUMN OWNER FORMAT A30
SELECT
   owner, table_name, TRUNC(sum(bytes)/1024/1024) TOTAL_SIZE_MB
FROM
(SELECT segment_name table_name, owner, bytes
 FROM dba_segments
 WHERE segment_type = 'TABLE'
 UNION ALL
 SELECT i.table_name, i.owner, s.bytes
 FROM dba_indexes i, dba_segments s
 WHERE s.segment_name = i.index_name
 AND   s.owner = i.owner
 AND   s.segment_type = 'INDEX'
 UNION ALL
 SELECT l.table_name, l.owner, s.bytes
 FROM dba_lobs l, dba_segments s
 WHERE s.segment_name = l.segment_name
 AND   s.owner = l.owner
 AND   s.segment_type = 'LOBSEGMENT'
 UNION ALL
 SELECT l.table_name, l.owner, s.bytes
 FROM dba_lobs l, dba_segments s
 WHERE s.segment_name = l.index_name
 AND   s.owner = l.owner
 AND   s.segment_type = 'LOBINDEX')
WHERE owner= UPPER('${OWNER}')
and table_name = UPPER('${OBJECT_NAME}')
GROUP BY table_name, owner
--HAVING SUM(bytes)/1024/1024 > 10  /* Ignore really small tables */
ORDER BY SUM(bytes) desc;

PROMPT
PROMPT
PROMPT INDEXES On the Table:
PROMPT ---------------------

set pages 100
set heading on
COLUMN OWNER FORMAT A25 heading "Index Owner"
COLUMN INDEX_NAME FORMAT A35 heading "Index Name"
COLUMN COLUMN_NAME FORMAT A30 heading "On Column"
COLUMN COLUMN_POSITION FORMAT 9999 heading "Pos"
COLUMN "INDEX" FORMAT A40
COLUMN TABLESPACE_NAME FOR A25
COLUMN INDEX_TYPE FOR A15
SELECT IND.OWNER||'.'||IND.INDEX_NAME "INDEX",
       IND.INDEX_TYPE,
       COL.COLUMN_NAME,
       COL.COLUMN_POSITION,
       IND.TABLESPACE_NAME,
       IND.STATUS,
       IND.UNIQUENESS,
       IND.LAST_ANALYZED
FROM   SYS.DBA_INDEXES IND,
       SYS.DBA_IND_COLUMNS COL
WHERE  IND.TABLE_NAME = upper('$OBJECT_NAME')
AND    IND.TABLE_OWNER = upper('$OWNER')
AND    IND.TABLE_NAME = COL.TABLE_NAME
AND    IND.OWNER = COL.INDEX_OWNER
AND    IND.TABLE_OWNER = COL.TABLE_OWNER
AND    IND.INDEX_NAME = COL.INDEX_NAME;

PROMPT
PROMPT
PROMPT CONSTRAINTS On the Table:
PROMPT -------------------------

col type format a10
col constraint_name format a40
COL COLUMN_NAME FORMAT A25 heading "On Column"
select	decode(d.constraint_type,
		'C', 'Check',
		'O', 'R/O View',
		'P', 'Primary',
		'R', 'Foreign',
		'U', 'Unique',
		'V', 'Check view') type
,	d.constraint_name
,       c.COLUMN_NAME
,	d.status
,	d.last_change
from	dba_constraints d, dba_cons_columns c
where	d.owner = upper('$OWNER')
and	d.table_name = upper('$OBJECT_NAME')
and	d.OWNER=c.OWNER
and	d.CONSTRAINT_NAME=c.CONSTRAINT_NAME
order by 1;

PROMPT
PROMPT
PROMPT Foreign Keys WITHOUT INDEX: [Recommended to Index them to Avoid Bad Performance (On OLTP only)]
PROMPT ---------------------------

col constraint_name format a40
COL COLUMN_NAME FORMAT A25 heading "On Column"
select 	acc.CONSTRAINT_NAME,
	acc.COLUMN_NAME,
	acc.POSITION,
	'No Index' Problem
from   	dba_cons_columns acc, 
	dba_constraints ac
where  	ac.CONSTRAINT_NAME = acc.CONSTRAINT_NAME
and   	ac.CONSTRAINT_TYPE = 'R'
and     acc.OWNER =upper('$OWNER')
and	acc.TABLE_NAME =upper('$OBJECT_NAME')
and     not exists (
        select  'TRUE' 
        from    dba_ind_columns b
        where   b.TABLE_OWNER = acc.OWNER
        and     b.TABLE_NAME = acc.TABLE_NAME
        and     b.COLUMN_NAME = acc.COLUMN_NAME
        and     b.COLUMN_POSITION = acc.POSITION)
order   by acc.OWNER, acc.CONSTRAINT_NAME, acc.COLUMN_NAME, acc.POSITION;

PROMPT
PROMPT
PROMPT DMLs On the Table:
PROMPT -------------------

col TRUNCATED for a9
col LAST_DML_DATE for a13
select INSERTS,UPDATES,DELETES,TRUNCATED,TIMESTAMP LAST_DML_DATE from DBA_TAB_MODIFICATIONS where TABLE_OWNER= upper('$OWNER') and TABLE_NAME= upper('$OBJECT_NAME');

PROMPT
PROMPT Getting Number of ROWS ...
PROMPT -----------------------

set heading off
select count(*) from $OWNER.$OBJECT_NAME;


PROMPT
PROMPT
PROMPT Last ROW In the Table:
PROMPT ----------------------

set heading on
select * from $OWNER.$OBJECT_NAME where rowid=(select max(rowid) from $OWNER.$OBJECT_NAME);
PROMPT
EOF

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
