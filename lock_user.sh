# #################################################
# Script to unlock locked users		#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	24-12-11	    #   #   # #   # 
# Modified:	31-12-13	     
#		Customized the script to run on
#		various environments.
#		16-09-14 Removed User Confirmation.
#
#
# #################################################
SCRIPT_NAME="lock_user"
# ###########
# Description:
# ###########
echo
echo "================================="
echo "This script LOCKS database users."
echo "================================="
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
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|grep -v ASM|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# If there is more than one DB ASK the user to select:
elif [ $INS_COUNT -gt 1 ]
 then
    echo
    echo "Select the ORACLE_SID:[Enter the number]"
    echo ---------------------
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|grep -v ASM|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
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
CURR_USER=`whoami`
	if [ ${ORA_USER} != ${CURR_USER} ]; then
	  echo ""
	  echo "You're Running This Sctipt with User: \"${CURR_USER}\" !!!"
	  echo "Please Run This Script With The Right OS User: \"${ORA_USER}\""
	  echo "Script Terminated!"
	  exit
	fi


# #############################
# SQLPLUS: Lock An Oracle User:
# #############################
# Variables
echo 
echo "Please enter the USERID:"
echo "======================="
while read USERNAME2
 do
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME=upper('$USERNAME2');
EOF
)
VAL22=`echo $VAL11| awk '{print $NF}'`
                        case ${VAL22} in
			# If the provided value match an exist username in the DB:
			1) 
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT USERNAME,ACCOUNT_STATUS FROM DBA_USERS WHERE USERNAME=upper('$USERNAME2');
PROMPT 
PROMPT Locking user [${USERNAME2}] ...
PROMPT
EOF
VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
ALTER user $USERNAME2 ACCOUNT LOCK;
EOF
)
VAL2=`echo $VAL1| grep "User altered"`
	                if [ -z "${VAL2}" ]
        	         then
                	  echo "Failed to lock User \"${USERNAME2}\" !"
		  	  echo
                  	  exit
                	 else
                  	  echo
                  	  echo User ${USERNAME2} locked Successfully.
                  	  echo
                	fi; break;;
			# If no value provided or the value doesn't match any user in the DB try to search for matching:
                        *) echo; echo "INFO: USER [${USERNAME2}] IS NOT EXIST ON DATABASE [$ORACLE_SID] !"
                           echo; echo "Searching ..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
col USERNAME for a30
col account_status for a23
select username,account_status,profile,LOCK_DATE,EXPIRY_DATE from dba_users where username like upper ('%$USERNAME2%');
EOF
                           echo; echo "Please Enter the FULL USERID:"
				 echo "=============================" ;;
                        esac
 done


# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
