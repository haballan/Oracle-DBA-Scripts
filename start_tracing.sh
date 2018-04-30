# #################################################
# Script to Enable tracing for an Oracle Session.		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	24-12-11	    #   #   # #   # 
# Modified:	31-12-13	     
#		Customized the script to run on
#		various environments.
#		04-05-14 Enhanced search criteria
#			 for generated trace file.
#
# #################################################

# ###########
# Description:
# ###########
echo
echo "=================================================="
echo "This script Enables tracing for an Oracle Session."
echo "=================================================="
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

# #########################
# Getting UDUMP Location:
# #########################
VAL_DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt 
SELECT value from v\$parameter where NAME='user_dump_dest';
exit;
EOF
)
UDUMP=`echo ${VAL_DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
export UDUMP

# #################################
# SQLPLUS: Start Tracing a Session:
# #################################
# Variables:
# #########
echo "" 
echo "Please enter the Username you want to trace its session:"
echo "========================================================"
read USERNAME
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
col USERNAME for a35
col MODULE for a30
Select username,module,SQL_ID "Curr_SQLID",prev_sql_id "Prev_SQLID",status,sid,serial#
from v\$session
where username like upper ('%$USERNAME%');
EOF

# Unlock Execution part:
echo 
echo "Enter the session SID:"
echo "---------------------"
read SESSIONID
	if [ -z "${SESSIONID}" ]
	 then
	  echo No Value Entered!
	  echo Script Terminated.
	  exit
	fi
echo "Enter the session SERIAL#:"
echo "-------------------------"
read SESSIONSERIAL
        if [ -z "${SESSIONSERIAL}" ]
         then
          echo "No Value Entered!"
          echo "Script Terminated."
          exit
        fi

VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
begin
dbms_monitor.session_trace_enable (
session_id => '$SESSIONID',
serial_num => '$SESSIONSERIAL',
waits => true,
binds => true
);
end;
/
EOF
)
VAL2=`echo $VAL1| grep "successfully completed"`
		if [ -z "${VAL2}" ]
		 then
		  echo
		  echo "The Session with Provided SID & SERIAL# is NOT EXIST!"
		  echo "Script Terminated."
		  echo
		  exit
		fi
echo

VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT p.spid FROM v\$session s,v\$process p WHERE p.addr = s.paddr and s.sid='$SESSIONID' and s.serial#='$SESSIONSERIAL';
EOF
)
VAL22=`echo $VAL11| awk '{print $NF}'`

VAL33=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT INSTANCE_NAME FROM V\$INSTANCE;
EOF
)
VAL44=`echo $VAL33| awk '{print $NF}'`

echo "TRACING has been ENABLED for session SID:${SESSIONID} / SERIAL#:${SESSIONSERIAL}"
TRACEFILE=`find ${UDUMP}/${VAL44}_ora_${VAL22}.trc -mmin -10|tail -1`
sleep 1
echo
echo "Trace File Location:"
echo "-------------------"
        if [ -z ${TRACEFILE} ]
         then
	  echo "Once the session start doing activities, try to find the TRACE FILE using the following command:"
	  echo "find ${UDUMP}/${VAL44}_ora_${VAL22}.trc -mmin -10"
         else
          echo "Trace File is: ${TRACEFILE}"
        fi
echo
sleep 2
echo -e "\033[33;9mDon't forget to STOP the Tracing once you Finish, Using 'stoptrace' Script.\033[0m"
echo

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
