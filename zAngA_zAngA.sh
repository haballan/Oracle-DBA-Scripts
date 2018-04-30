# #################################################
# This script shows AUDIT records for a user.
# To be run by ORACLE user		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	25-04-2013	    #   #   # #   # 
#
# #################################################

# ###########################
# Listing Available Instances:
# ###########################

echo
echo "=================================================================="
echo "This Script Retreives AUDIT data for a user if auditing is enabled."
echo "=================================================================="
echo
sleep 1

# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"                           #Excluded INSTANCES [Will not get reported offline].

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
    echo "Select the Instance You Want To Run this script Against:[Enter the number]"
    echo "-------------------------------------------------------"
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
# SQLPLUS Section:
# #########################
# PROMPT FOR VARIABLES:
# ####################

echo
echo "Enter The USERNAME you want to retrieve its Audit Data: [Blank Value means ALL Users]"
echo "======================================================"
while read DB_USERNAME
        do
                case $DB_USERNAME in
                  # NO VALUE PROVIDED:
                  "") USERNAME_COND=$DB_USERNAME;break ;;
                   *) USERNAME_COND="USERNAME=upper('$DB_USERNAME') and";break ;;
                esac
        done

echo
echo "How [MANY DAYS BACK] you want to retrieve AUDIT data? [Default 1]"
echo "====================================================="
echo "OR: Enter A Specific DATE in this FORMAT [DD-MM-YYYY] e.g. 25-01-2011"
echo "==  ================================================================="
while read NUM_DAYS
        do
                case $NUM_DAYS in
		  # User PROVIDED a NON NUMERIC value:
		  *[!0-9]*) echo;echo "Retreiving AUDIT data for User [${DB_USERNAME}] on [${NUM_DAYS}] ..."
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set linesize 157
col OS_USERNAME for a15
col USERNAME for a15
--col EXTENDED_TIMESTAMP for a36
col DATE for a22
col OWNER for a10
col OBJ_NAME for a25
col USERHOST for a21
col ACTION_NAME for a25
col ACTION_OWNER_OBJECT for a55
--select extended_timestamp,OS_USERNAME,USERNAME,USERHOST,ACTION_NAME||'  '||OWNER||' . '||OBJ_NAME ACTION_OWNER_OBJECT
select to_char(extended_timestamp,'DD-Mon-YYYY HH24:MI:SS')"DATE",OS_USERNAME,USERNAME,USERHOST,ACTION_NAME||'  '||OWNER||' . '||OBJ_NAME ACTION_OWNER_OBJECT
from dba_audit_trail
where $USERNAME_COND
ACTION_NAME not like 'LOGO%'
and TRUNC(extended_timestamp) = TO_DATE('$NUM_DAYS','DD-MM-YYYY') order by EXTENDED_TIMESTAMP;
PROMPT LOGON/LOGOFF Audit data have been ommited from this report.
PROMPT
EOF
exit
		     break ;;
                  # NO VALUE PROVIDED:
                  "") NUM_DAYS=1;echo;echo "Retreiving AUDIT data in the last 24 Hours ... [Please Wait]";break ;;
                  # A NUMERIC VALUE PROVIDED:
                  *) echo;echo "Retreiving AUDIT data in the last ${NUM_DAYS} Days ... [Please Wait]";break ;;
                esac
        done

# Execution of SQL Statement:
# ##########################

${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set linesize 190 pages 1000
col OS_USERNAME for a15
col USERNAME for a15
--col EXTENDED_TIMESTAMP for a36
col DATE for a22
col OWNER for a10
col OBJ_NAME for a25
col USERHOST for a21
col ACTION_NAME for a25
col ACTION_OWNER_OBJECT for a80
--select extended_timestamp,OS_USERNAME,USERNAME,USERHOST,ACTION_NAME||'  '||OWNER||' . '||OBJ_NAME ACTION_OWNER_OBJECT
select to_char(extended_timestamp,'DD-Mon-YYYY HH24:MI:SS')"DATE",OS_USERNAME,USERNAME,USERHOST,ACTION_NAME||'  '||OWNER||' . '||OBJ_NAME ACTION_OWNER_OBJECT
from dba_audit_trail 
where $USERNAME_COND
ACTION_NAME not like 'LOGO%' 
and timestamp > SYSDATE-$NUM_DAYS order by EXTENDED_TIMESTAMP;
PROMPT [NOTE: LOGON/LOGOFF records were ommited from this report.]
PROMPT
EOF

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
