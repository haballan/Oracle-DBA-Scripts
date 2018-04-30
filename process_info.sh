# ##################################################
# Script to Show Previous & Current Running SQL STMT
# Author:       Mahmmoud ADEL        	#   #     #
# Created:      24-01-11 	      # # # #   ###
# Modified:	24-12-13	    #   #   # #   # 
#		Customized the script to run on
#		various environments.
#		01-05-14	Added wait details.
#		01-05-14	Fix bug of more than
#				process contain the
#				same process ID.
#
# ##################################################

# ###########
# Description:
# ###########
echo
echo "================================================================="
echo "This script Displays Oracle session Details for an OS process ID."
echo "================================================================="
echo
sleep 1

# Variables:
echo "Please Enter the Unix Process ID:"
echo "================================="
read "SPID"

# ###########################
# Getting ORACLE_SID:
# ###########################
#CHK1=`ps -ef| grep ${SPID} | grep -v grep | grep LOCAL`
CHK1=`ps -ef| grep ${SPID} | grep -v grep`

	if [ -z "${CHK1}" ]
	 then
	  echo "This Script Is Not Designed For Such Proccess!"
	  echo "This Script Works With Oracle Sessions PIDs Having (LOCAL=YES) or (LOCAL=NO) attribute."
	  exit
	fi

ORACLE_SID=`ps -ef | grep " ${SPID} " | grep -v grep | awk '{print $(NF-1)}'| sed -e 's/oracle//g' | grep -v sed | grep -v "s///g"`

	if [ -z "${ORACLE_SID}" ]
	 then
	  echo "Can Not Obtain A Valid ORACLE_SID, Please check the process ID you have entered and try again."
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

# #############################################
# SQLPLUS: Show Previous/Current SQL Statement:
# #############################################

# SQL Script:
${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" << EOF

Prompt Session Details:
Prompt ----------------

set feedback off linesize 180 pages 1000
col module for a27
col "USERNAME | SID,SERIAL#" for a35
col "ST|WA_ST|WAITD|ACT_SINC|LOG_T" for a35
col event for a28
select s.USERNAME||' | '||s.sid||','||s.serial# "USERNAME | SID,SERIAL#",s.MODULE,
substr(s.status||'|'||w.state||'|'||w.seconds_in_wait||'|'||LAST_CALL_ET||'|'||to_char(LOGON_TIME,'ddMon HH24:MI'),1,40) "ST|WA_ST|WAITD|ACT_SINC|LOG_T",
w.event,s.PREV_SQL_ID,s.SQL_ID CURR_SQL_ID
from v\$session s,v\$process p, v\$session_wait w
where p.spid=$SPID and p.addr = s.paddr
and p.addr = s.paddr
and s.sid=w.sid;

Prompt
col "Previous SQL" for a156
select q.SQL_FULLTEXT "Previous SQL" from v\$process p,v\$session s ,v\$sql q where p.spid=$SPID and p.addr = s.paddr and q.sql_id=s.PREV_SQL_ID;

prompt
col "Current SQL" for a156
select q.SQL_FULLTEXT "Current SQL" from v\$process p,v\$session s ,v\$sql q where p.spid=$SPID and p.addr = s.paddr and q.sql_id=s.sql_id;
EOF

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
