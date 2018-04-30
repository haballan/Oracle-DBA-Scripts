# ##################################################################################
# Checking long running queries run by specific user
# [Ver 1.0]
#
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      09-03-17            #   #   # #   #  
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
#
#
#
# ##################################################################################

SCRIPT_NAME="report_long_runing_queries"
SRV_NAME=`uname -n`
MAIL_LIST="youremail@yourcompany.com"

        case ${MAIL_LIST} in "youremail@yourcompany.com")
         echo
         echo "****************************************************************************************************"
         echo "Buddy! You will not receive an E-mail with the result, because you didn't set MAIL_LIST variable yet"
         echo "Just replace youremail@yourcompany.com with your right email."
         echo "****************************************************************************************************"
         echo 
        esac


# #########################
# THRESHOLDS:
# #########################
# Modify the THRESHOLDS to the value you prefer:

EXEC_TIME_IN_MINUTES=60		# Report Sessions running longer than N minutes (default is 60 min).
LONG_RUN_SESS_COUNT=0		# The count of long running sessions, report will not appear unless reached (0 report all long running sessions).

export EXEC_TIME_IN_MINUTES
export LONG_RUN_SESS_COUNT


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"                           #Excluded INSTANCES [Will not get reported offline].


# #########################
# SQLPLUS Output Format:
# #########################
SQLLINESIZE=160
SQLPAGES=1000
SQLLONG=999999999

export SQLLINESIZE
export SQLPAGES
export SQLLONG


# ##########################
# Neutralize login.sql file: [Bug Fix]
# ##########################
# Existance of login.sql file under Oracle user Linux home directory eliminates many functions during the execution of this script from crontab:

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi


# #########################
# Setting ORACLE_SID:
# #########################
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

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
mail -s "dbalarm script on Server [${SRV_NAME}] failed to find ORACLE_HOME, Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory" $MAIL_LIST < /dev/null
exit
fi

# #########################
# Variables:
# #########################
export PATH=$PATH:${ORACLE_HOME}/bin
export LOG_DIR=${USR_ORA_HOME}/BUNDLE_Logs
mkdir -p ${LOG_DIR}
chown -R ${ORA_USER} ${LOG_DIR}
chmod -R go-rwx ${LOG_DIR}

        if [ ! -d ${LOG_DIR} ]
         then
          mkdir -p /tmp/BUNDLE_Logs
          export LOG_DIR=/tmp/BUNDLE_Logs
          chown -R ${ORA_USER} ${LOG_DIR}
          chmod -R go-rwx ${LOG_DIR}
        fi

export LOGFILE=${LOG_DIR}/reported_long_running_sessions.log


# ##########################
# Neutralize login.sql file: [Bug Fix]
# ##########################
# Existance of login.sql file under Oracle user Linux home directory eliminates many functions during the execution of this script from crontab:

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi


# #########################
# Getting ORACLE_HOME
# #########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|grep -v ASM|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

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

## If oratab is not exist, or ORACLE_SID not added to oratab, find ORACLE_HOME in user's profile:
if [ -z "${ORACLE_HOME}" ]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash* $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
fi



# Check the Long Running Session Count:
LONG_RUN_COUNT_RAW2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from v\$session
where
-- To capture active session for more than defined EXEC_TIME_IN_MINUTES variable in minutes:
last_call_et > 60*${EXEC_TIME_IN_MINUTES}
and username is not null 
and module is not null
and status = 'ACTIVE';
exit;
EOF
)

LONG_RUN_COUNT2=`echo ${LONG_RUN_COUNT_RAW2}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

  if [ ${LONG_RUN_COUNT2} -gt ${LONG_RUN_SESS_COUNT} ]
   then
# Long running query output:
LONG_QUERY_DETAIL2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set linesize ${SQLLINESIZE} pages ${SQLPAGES}
set long ${SQLLONG}
col module for a30
col DURATION_HOURS for 99999.9
col STARTED_AT for a13
col "USERNAME| SID,SERIAL#" for a30
col "SQL_ID | SQL_TEXT" for a${SQLLINESIZE}
spool ${LOGFILE}
select username||'| '||sid ||','|| serial# "USERNAME| SID,SERIAL#",substr(MODULE,1,30) "MODULE", to_char(sysdate-last_call_et/24/60/60,'DD-MON HH24:MI') STARTED_AT,
last_call_et/60/60 "DURATION_HOURS"
,SQL_ID ||' | '|| (select SQL_FULLTEXT from v\$sql where address=sql_address and CHILD_NUMBER=SQL_CHILD_NUMBER) "SQL_ID | SQL_TEXT"
--,SQL_ID ||' | '|| (select SQL_FULLTEXT from v\$sql where address=sql_address) "SQL_ID | SQL_TEXT"
--,SQL_ID
from v\$session
where
-- To capture active session for more than defined EXEC_TIME_IN_MINUTES variable in minutes:
last_call_et > 60*${EXEC_TIME_IN_MINUTES}
and username is not null 
and module is not null
and status = 'ACTIVE'
order by "DURATION_HOURS" desc;
spool off
exit;
EOF
)

cat ${LOGFILE}
/bin/mail -s "Info: Long Running Sessions on DB [${ORACLE_SID}] on Server [${SRV_NAME}]" ${MAIL_LIST} < ${LOGFILE}
  fi


done

# #############################
# De-Neutralize login.sql file:
# #############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}  ${USR_ORA_HOME}/login.sql
        fi


# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
