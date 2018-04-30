# ##############################################################################
# This script Backup & Delete the database logs.
# To be run by ORACLE user		
# [Ver 1.5]
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	03-06-2013	    #   #   # #   # 
# Modified:	02-07-2013
#		14-01-2014 Customized the script to run on various environments.
#		14-06-2017 Increased the script accuracy and elimiated tar
#			   command bug.
#
#
# ##############################################################################

# ###########
# Description:
# ###########
echo
echo "================================================"
echo "This script Backs up & Deletes the database logs ..."
echo "================================================"
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
# Listing Available Instances:
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
    echo "Select the Instance You Want To Backup & Delete It's Logs:[Enter the Number]"
    echo "----------------------------------------------------------"
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
	if [ -z "${REPLY##[0-9]*}" ]
	 then
          export ORACLE_SID=$DB_ID
	  echo Selected Instance:
	  echo "********"
	  echo $DB_ID
          echo "********"
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

# Neutralize login.sql file:
# #########################
# Existance of login.sql file under current working directory eliminates many functions during the execution of this script:

        if [ -f ./login.sql ]
         then
mv ./login.sql   ./login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# #########################
# Getting DB_NAME:
# #########################
VAL1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT name from v\$database
exit;
EOF
)
# Getting DB_NAME in Uppercase & Lowercase:
DB_NAME_UPPER=`echo $VAL1| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
DB_NAME_LOWER=$( echo "$DB_NAME_UPPER" | tr -s  '[:upper:]' '[:lower:]' )
export DB_NAME_UPPER
export DB_NAME_LOWER

# DB_NAME is Uppercase or Lowercase?:

     if [ -f $ORACLE_HOME/diagnostics/${DB_NAME_UPPER} ]
        then
                DB_NAME=$DB_NAME_UPPER
		export DB_NAME
        else
                DB_NAME=$DB_NAME_LOWER
                export DB_NAME
     fi

# ########################
# Getting ORACLE_BASE:
# ########################
# Get ORACLE_BASE from user's profile if not set:

if [ -z "${ORACLE_BASE}" ]
 then
   ORACLE_BASE=`grep 'ORACLE_BASE=\/' $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
   export ORACLE_BASE
fi

# #########################
# Getting ALERTLOG path:
# #########################
VAL_DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
BDUMP=`echo ${VAL_DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
export BDUMP
DUMP=`echo ${BDUMP} | sed 's/\/trace//g'`
export DUMP
CDUMP=${DUMP}/cdump
export CDUMP
ALERTDB=${BDUMP}/alert_${ORACLE_SID}.log
export ALERTDB

# #########
# Variables: 
# #########
echo ""
echo "Please Enter The Full Path of Backup Location: [/tmp]"
echo "============================================="
read LOC1
# Check if No location provided:
	if [ -z ${LOC1} ]; then
          LOC1=/tmp
          export LOC1
          echo "Database Logs Backup Will Be Saved Under: ${LOC1}"
	 else
	  export LOC1
	  echo "Database Logs Backup Will Be Saved Under: ${LOC1}"
	fi
# Check if provided location path is not exist:
        if [ ! -d ${LOC1} ]; then
	  echo ""
	  echo "Location Path \"${LOC1}\" is NOT EXIST!"
          echo "Script Terminated!"
	  exit
        fi

	
# Setting a Verifier:
echo ""
echo "Are You SURE to Backup & Remove the logs of Database \"${ORACLE_SID}\" and its Listener: [Y|N] Y"
echo "================================================================================="
while read ANS
  do
        case $ANS in
        ""|y|Y|yes|YES|Yes) echo;echo "Backing up & removing DB & Listener Logs ...";sleep 1;echo;break ;;
        n|N|NO|no|No) echo; echo "Script Terminated !";echo; exit; break ;;
        *) echo;echo "Please enter a VALID answer [Y|N]" ;;
        esac
  done

BKP_BASE=${LOC1}
export BKP_BASE
BKP_LOC_DB=$BKP_BASE/${ORACLE_SID}_logs/`uname -n`/`date '+%b_%Y'`
export BKP_LOC_DB
DB=${DB_NAME}
export DB
INS=${ORACLE_SID}
export INS

# ######################
# Getting Listener name:
# ######################
LSNR_COUNT=$( ps -ef|grep tnslsnr|grep -v grep|wc -l )

	if [ ${LSNR_COUNT} -eq 1 ]
	 then
	   LSNR_NAME=$( ps -ef|grep tnslsnr|grep -v grep|awk '{print $(9)}' )
	 else
           LSNR_NAME=$( ps -ef|grep tnslsnr|grep -i "${ORACLE_SID} "|grep -v grep|awk '{print $(9)}' )
	fi

        if [ -z "${LSNR_NAME}" ]
         then
           LSNR_NAME=LISTENER
        fi

LISTENER_NAME=${LSNR_NAME}

# Creating folder holds the logs:
mkdir -p ${BKP_LOC_DB}

# Backup & Delete DB logs:
# #######################
        if [ ! -d ${DUMP} ]
         then
          echo "The Parent Log Dump location cannot be Found!"
	  exit
        fi

tail -1000 ${ALERTDB} > ${BKP_LOC_DB}/alert_${INS}.log.keep
gzip -f9 ${BDUMP}/alert_${INS}.log 
mv ${BDUMP}/alert_${INS}.log.gz   		${BKP_LOC_DB}
mv ${BKP_LOC_DB}/alert_${INS}.log.keep 		${BDUMP}/alert_${INS}.log
#tar zcvfP ${BKP_LOC_DB}/${INS}-dump-logs.tar.gz ${DUMP}
find ${DUMP} -name '*' -print > 				${BKP_LOC_DB}/dump_files_list.txt
tar zcvfP ${BKP_LOC_DB}/${INS}-dump-logs.tar.gz --files-from 	${BKP_LOC_DB}/dump_files_list.txt


# Delete DB logs older than 5 days:
find ${BDUMP}         -type f -name '*.trc' -o -name '*.trm' -o -name '*.log' -mtime +5 -exec rm -f {} \;
find ${DUMP}/alert    -type f -name '*.xml'                                   -mtime +5 -exec rm -f {} \;
find ${DUMP}/incident -type f -name '*.trc' -o -name '*.trm' -o -name '*.log' -mtime +5 -exec rm -f {} \;
find ${CDUMP}         -type f -name '*.trc' -o -name '*.trm' -o -name '*.log' -mtime +5 -exec rm -f {} \;

# Backup & Delete listener's logs:
# ################################
#LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep -i ${LSNR_NAME}|awk '{print $(NF-2)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"|head -1`
LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep "${LSNR_NAME} "|awk '{print $(8)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"|head -1`
TNS_ADMIN=${LISTENER_HOME}/network/admin
export TNS_ADMIN
LSNLOGDR=`${LISTENER_HOME}/bin/lsnrctl status ${LISTENER_NAME}|grep "Listener Log File"| awk '{print $NF}'| sed -e 's/\/alert\/log.xml//g'`
LISTENER_LOG=${LSNLOGDR}/trace/${LISTENER_NAME}.log
echo LISTENER_HOME: $LISTENER_HOME
echo TNS_ADMIN: $TNS_ADMIN
echo LISTENER_LOG: $LISTENER_LOG

# Determine if the listener name is in Upper/Lower case:
        if [ -f ${LISTENER_LOG} ]
         then
          # Listner_name is Uppercase:
          LISTENER_NAME=$( echo ${LISTENER_NAME} | perl -lpe'$_ = reverse' |perl -lpe'$_ = reverse' )
          LISTENER_LOG=${LSNLOGDR}/trace/${LISTENER_NAME}.log
         else
          # Listener_name is Lowercase:
          LISTENER_NAME=$( echo "${LISTENER_NAME}" | tr -s  '[:upper:]' '[:lower:]' )
          LISTENER_LOG=${LSNLOGDR}/trace/${LISTENER_NAME}.log
        fi

	if [ ! -d ${LSNLOGDR} ]
	 then
          echo 'Listener Logs Location Cannot be Found!'
        fi
tar zcvfP ${BKP_LOC_DB}/${LISTENER_NAME}_trace.tar.gz  ${LSNLOGDR}/trace
tar zcvfP ${BKP_LOC_DB}/${LISTENER_NAME}_alert.tar.gz  ${LSNLOGDR}/alert
tail -10000 ${LSNLOGDR}/trace/${LISTENER_NAME}.log > ${BKP_LOC_DB}/${LISTENER_NAME}.log.keep
find ${LSNLOGDR}/trace -type f -name '*.trc' -o -name '*.trm' -o -name '*.log' -exec rm -f {} \;
find ${LSNLOGDR}/alert -type f -name '*.xml'                                   -exec rm -f {} \;
mv ${BKP_LOC_DB}/${LISTENER_NAME}.log.keep   ${LSNLOGDR}/trace/${LISTENER_NAME}.log

# ############################
# Backup & Delete AUDIT logs:
# ############################
# Getting Audit Files Location:
# ############################
VAL_AUD=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='audit_file_dest';
exit;
EOF
)
AUD_LOC=`echo ${VAL_AUD} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`

        if [ ! -d ${AUD_LOC} ]
         then
          echo 'Audit Files Location Cannot be Found!'
	  exit
        fi

#tar zcvfP ${BKP_LOC_DB}/audit_files.tar.gz ${AUD_LOC}/${ORACLE_SID}_*
find ${AUD_LOC} -type f -name '${ORACLE_SID}_*' -print > 		${BKP_LOC_DB}/audit_files_list.txt
tar zcvfP ${BKP_LOC_DB}/${INS}-audit-logs.tar.gz --files-from 		${BKP_LOC_DB}/audit_files_list.txt


# Delete Audit logs older than 5 days
#find ${AUD_LOC}/${ORACLE_SID}_* -type f -mtime +5 -exec rm {} \;
find ${AUD_LOC} -name '${ORACLE_SID}_*' -type f -mtime +5 -exec rm -f {} \;

echo ""
echo "------------------------------------"
echo "Old logs have been backed up under: ${BKP_LOC_DB}"
echo "The Last 5 Days Logs have been KEPT."
echo "CLEANUP COMPLETE."
echo "------------------------------------"
echo

# De-Neutralize login.sql file:
# ############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ./login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ./login.sql_NeutralizedBy${SCRIPT_NAME}  ./login.sql
        fi

        if [ -f ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}  ${USR_ORA_HOME}/login.sql
        fi

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
