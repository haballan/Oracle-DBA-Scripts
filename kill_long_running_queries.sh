# #######################################################################
# Kill queries running for more than N hours based on specific criteria.
# #######################################################################
VER="[1.0]"
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      11-01-18            #   #   # #   #  
#
#
#
#
# #######################################################################

# #####################
# Environment Variables: [ORACLE_SID must be set by the user in case multiple instances running]
# #####################
export ORACLE_SID=

export SCRIPT_NAME="kill_long_running_queries"
export SRV_NAME=`uname -n`
#export LNXVER=`cat /etc/redhat-release | grep -o '[0-9]'|head -1`
export LOGFILE=/tmp/${SCRIPT_NAME}.log
export TERMINATOR_SCRIPT=/tmp/KILL_LONG_QUERIES.sql

# Email Recipients:
# ################
MAIL_LIST="youremail@yourcompany.com"
export MAIL_LIST


# #######################################
# SCRIPT OPTIONS:
# #######################################

# #################
# KILLING Criteria:
# #################

# Module Name: [Put "," between each module name and keep each module name between single quote]
# e.g. export MODULE_NAME="'SQL Developer','Toad'"
export MODULE_NAME="'SQL Developer'"

# Duration [In hours and its fraction] when exceeded the query will get killed:
# e.g. To kill the queries that exceed 3 hours and 30 minutes export DURATION="3.5"
export DURATION="2.5"

# Report Only Semaphore: [The script will NOT KILL any query if it set to Y but will report them to the user]
# Y to report long sessions by email without killing them.
# N to Kill long sessions and report them after killing to the user. [Default]
export REPORT_ONLY="N"

	case ${REPORT_ONLY} in
	Y|y|yes|Yes|YES) export HASH_SCRIPT="--";export REPORT_ONLY_MESSAGE="PROMPT REPORT_ONLY Semaphore is set to Y, No Killing will happen";;
	*) 		 export HASH_SCRIPT="";export REPORT_ONLY_MESSAGE="";;
	esac


# ####################################################################
# Check if ORACLE_SID & MAIL_LIST variables is already set by the user:
# ####################################################################

export EXL_DB="\-MGMTDB|ASM"	# Instances to not be considered when running the script
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )

        case ${ORACLE_SID} in "")
                # Exit if No DBs are running:
                if [ ${INS_COUNT} -eq 0 ]
                 then
                   echo No Database Running !
                   exit
                fi

                # If there is ONLY one DB make it the default ORACLE_SID:
                if [ ${INS_COUNT} -eq 1 ]
                then
                   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

                # If there is more than one DB ASK the user to set the ORACLE_SID manually:
                elif [ ${INS_COUNT} -gt 1 ]
                 then
                  echo
                  echo
                  echo "*****"
                  echo "ERROR! You have to manually set ORACLE_SID to one of the following instances in the 'Environment Variables' Section!"
                  echo "*****"
                        ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g"
                  echo
                  echo "Script Terminated !"
                  echo 
                  exit
                fi
        ;;
        esac


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

# ###########
# SCRIPT BODY:
# ###########

# Script Description:
echo ""
echo "This Script Kills the sessions running a query for more than ${DURATION} hours and connecting from ${MODULE_NAME} ..."
sleep 1

# Flush the logfile:
cat /dev/null > ${LOGFILE}


# CHECKING RUNNING SESSIONS:
SESSIONS_COUNT_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from V\$SESSION where
MODULE in (${MODULE_NAME})
and last_call_et > 60*60*${DURATION}
and status = 'ACTIVE'
;
exit;
EOF
)

SESSIONS_COUNT=`echo ${SESSIONS_COUNT_RAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# KILLING LONG RUNNING SESSIONS IF EXIST:
# ######################################

	if [ ${SESSIONS_COUNT} -gt 0 ]
	 then
echo "Found ${SESSIONS_COUNT} Candidate sessions to be killed!"
KILL_SESSION_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
spool ${LOGFILE} APPEND
set pages 0 feedback off
prompt
PROMPT *****

select 'TIME: '||to_char(systimestamp, 'dd-Mon-yy HH24:MI:SS') from dual;
PROMPT *****

set linesize 170 pages 1000;
prompt
prompt Session Details: [To be killed]
prompt ***************

col inst for 99
col module for a27
col event for a28
col MACHINE for a27
col "ST|ACT_SINC|LOG_TIME" for a51
col "USER|OSUSER|SID,SER|MACHIN|MODUL" for a75
select substr(s.USERNAME||'|'||s.OSUSER||'|'||s.sid||','||s.serial#||'|'||substr(s.MACHINE,1,25)||' | '||substr(s.MODULE,1,25),1,75)"USER|OS|SID,SER|MACHIN|MODUL"
,substr(s.status||'|'||LAST_CALL_ET||'|'||LOGON_TIME,1,50) "ST|ACT_SINC|LOG_TIME"
,s.SQL_ID CURR_SQL_ID
from v\$session s
where
MODULE in (${MODULE_NAME})
and last_call_et > 60*60*${DURATION}
and status = 'ACTIVE'
;

spool off

-- Kill SQL Script creation:
set pages 0 feedback off echo off
spool ${TERMINATOR_SCRIPT}

select 'ALTER SYSTEM DISCONNECT SESSION '''||sid||','||serial#||''' IMMEDIATE;'
from V\$SESSION
where
MODULE in (${MODULE_NAME})
and last_call_et > 60*60*${DURATION}
and status = 'ACTIVE'
;

spool off

-- Run the Terminator Script to kill the sessions:
set pages 1000 feedback on echo on
spool ${LOGFILE} APPEND
PROMPT
PROMPT Running The Terminator Script:
PROMPT *****************************

${REPORT_ONLY_MESSAGE}
${HASH_SCRIPT}START ${TERMINATOR_SCRIPT}

spool off
exit;
EOF
)

sleep 10

CURRENT_LONG_SESS_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set linesize 170 pages 1000;
spool ${LOGFILE} APPEND
prompt
prompt CHECK For other long queries fulfill the killing criteria: [Still Running]
prompt *********************************************************

col inst for 99
col module for a27
col event for a28
col MACHINE for a27
col "ST|ACT_SINC|LOG_TIME" for a51
col "USER|SID,SER|MACHIN|MODUL" for a72
select substr(s.USERNAME||'|'||s.sid||','||s.serial#||'|'||substr(s.MACHINE,1,25)||' | '||substr(s.MODULE,1,25),1,72)"USER|SID,SER|MACHIN|MODUL"
,substr(s.status||'|'||LAST_CALL_ET||'|'||LOGON_TIME,1,50) "ST|ACT_SINC|LOG_TIME"
,s.SQL_ID CURR_SQL_ID
from v\$session s
where
MODULE in (${MODULE_NAME})
and last_call_et > 60*60*${DURATION}
and status = 'ACTIVE'
;

spool off
exit;
EOF
)

# EMAIL Notification with the killed session:
  case ${MAIL_LIST} in
	"youremail@yourcompany.com");;
	*) 
/bin/mail -s "Info: Long Running QUERY KILLED on [${ORACLE_SID}]" ${MAIL_LIST} < ${LOGFILE};;
  esac

        else
        echo ""
        echo "Hooray! No Candidate Sessions were found based on the Killing Criteria."
        echo ""
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
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
