# #####################################################################
# This script takes a RMAN Backup a database.
# [Ver 4.0]
#						#   #     #
# Author:	Mahmmoud ADEL	      	      # # # #   ###
# Created:	24-09-11	    	    #   #   # #   # 
# Modified:	31-12-13	     
#		Customized the script to run on
#		various environments.
#		12-03-16 Run RMAN command in the background
#         	         to avoid job fail when session terminate.
#		23-08-16 Added Backup Encryption Option.
#		17-11-16 Added Channels Number feature.
#		22-01-18 Added Controlfile compressed backup option.
#
# #####################################################################

# ###########
# Description:
# ###########
echo
echo "==================================================="
echo "This script Takes a RMAN FULL Backup of a database."
echo "==================================================="
echo
sleep 1

# ###########################
# CPU count check:
# ###########################

# Count of CPUs:
CPU_NUM=`cat /proc/cpuinfo|grep CPU|wc -l`
export CPU_NUM


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

# ###############################
# RMAN: Script Creation:
# ###############################
# Last RMAN Backup Info:
# #####################
export NLS_DATE_FORMAT='DD-Mon-YYYY HH24:MI:SS'
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 170 pages 200
PROMPT LAST 14 DAYS RMAN BACKUP DETAILS:
PROMPT ---------------------------------

set linesize 160
set feedback off
col START_TIME for a15
col END_TIME for a15
col TIME_TAKEN_DISPLAY for a10
col INPUT_BYTES_DISPLAY heading "DATA SIZE" for a10
col OUTPUT_BYTES_DISPLAY heading "Backup Size" for a11
col OUTPUT_BYTES_PER_SEC_DISPLAY heading "Speed/s" for a10
col output_device_type heading "Device_TYPE" for a11
SELECT to_char (start_time,'DD-MON-YY HH24:MI') START_TIME, to_char(end_time,'DD-MON-YY HH24:MI') END_TIME, time_taken_display, status,
input_type, output_device_type,input_bytes_display, output_bytes_display, output_bytes_per_sec_display,COMPRESSION_RATIO COMPRESS_RATIO
FROM v\$rman_backup_job_details
WHERE end_time > sysdate -14;

EOF

# Variables:
export NLS_DATE_FORMAT="DD-MON-YY HH24:MI:SS"

# Building the RMAN BACKUP Script:
echo;echo 
echo Please enter the Backup Location: [e.g. /backup/DB]
echo "================================"
while read BKPLOC1
	do
		/bin/mkdir -p ${BKPLOC1}/RMANBKP_${ORACLE_SID}/`date '+%F'`
		BKPLOC=${BKPLOC1}/RMANBKP_${ORACLE_SID}/`date '+%F'`

		if [ ! -d "${BKPLOC}" ]; then
        	 echo "Provided Backup Location is NOT Exist/Writable !"
		 echo 
	         echo "Please Provide a VALID Backup Location:"
		 echo "--------------------------------------"
		else
		 break
        	fi
	done
echo
echo "Backup Location is: ${BKPLOC1}"
echo
echo "How many CHANNELS do you want to allocate for this backup? [${CPU_NUM} CPUs Available On This Machine]"
echo "========================================================="
while read CHANNEL_NUM
	do
		integ='^[0-9]+$'
		if ! [[ ${CHANNEL_NUM} =~ $integ ]] ; then
   			echo "Error: Not a valid number !"
			echo
			echo "Please Enter a VALID NUMBER:"
			echo "---------------------------"
		else
			break
		fi
	done
echo
echo "Number Of Channels is: ${CHANNEL_NUM}"
echo
echo "---------------------------------------------"
echo "COMPRESSED BACKUP will allocate SMALLER space"
echo "but it's a bit SLOWER than REGULAR BACKUP."
echo "---------------------------------------------"
echo
echo "Do you want a COMPRESSED BACKUP? [Y|N]: [Y]"
echo "================================"
while read COMPRESSED
	do
		case $COMPRESSED in  
		  ""|y|Y|yes|YES|Yes) COMPRESSED=" AS COMPRESSED BACKUPSET "; echo "COMPRESSED BACKUP ENABLED.";break ;; 
		  n|N|no|NO|No) COMPRESSED="";break ;; 
		  *) echo "Please enter a VALID answer [Y|N]" ;;
		esac
	done

echo
echo "Do you want to ENCRYPT the BACKUP by Password? [Available in Enterprise Edition only] [Y|N]: [N]"
echo "=============================================="
while read ENCR_BY_PASS_ANS
        do
                case ${ENCR_BY_PASS_ANS} in
                  y|Y|yes|YES|Yes)
		  echo
		  echo "Please Enter the password that will be used to Encrypt the backup:"
		  echo "-----------------------------------------------------------------"
		  read ENCR_PASS
		  ENCR_BY_PASS="SET ENCRYPTION ON IDENTIFIED BY '${ENCR_PASS}' ONLY;"
		  export ENCR_BY_PASS
		  echo
		  echo "BACKUP ENCRYPTION ENABLED."
		  echo
		  echo "Later, To RESTORE this backup please use the following command to DECRYPT it, placing it just before the RESTORE Command:"
		  echo "  e.g."
		  echo "  SET DECRYPTION IDENTIFIED BY '${ENCR_PASS}';"
		  echo "  restore database ...."
		  echo
		  break ;;
                  ""|n|N|no|NO|No) ENCR_BY_PASS="";break ;;
                  *) echo "Please enter a VALID answer [Y|N]" ;;
                esac
        done

RMANSCRIPT=${BKPLOC}/RMAN_FULL_${ORACLE_SID}.rman
RMANSCRIPTRUNNER=${BKPLOC}/RMAN_FULL_nohup.sh
RMANLOG=${BKPLOC}/rmanlog.`date '+%a'`

echo "${ENCR_BY_PASS}"      > ${RMANSCRIPT}
echo "run {" 		   >> ${RMANSCRIPT}
CN=1
while [[ ${CN} -le ${CHANNEL_NUM} ]]
do
echo "allocate channel C${CN} type disk;" >> ${RMANSCRIPT}
    ((CN = CN + 1))
done
echo "CHANGE ARCHIVELOG ALL CROSSCHECK;" >> ${RMANSCRIPT}
#echo "DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;" >> ${RMANSCRIPT}
echo "BACKUP ${COMPRESSED} INCREMENTAL LEVEL=0 FORMAT '${BKPLOC}/%d_%I_%t_%s_%p' TAG='FULLBKP'" >> ${RMANSCRIPT}
echo "FILESPERSET 100 DATABASE include current controlfile PLUS ARCHIVELOG;" >> ${RMANSCRIPT}
#echo "BACKUP FORMAT '${BKPLOC}/%d_%t_%s_%p.ctl' TAG='CONTROL_BKP' CURRENT CONTROLFILE;" >> ${RMANSCRIPT}
echo "BACKUP ${COMPRESSED} FORMAT '${BKPLOC}/CONTROLFILE_%d_%I_%t_%s_%p.bkp' REUSE TAG='CONTROL_BKP' CURRENT CONTROLFILE;" >> ${RMANSCRIPT}
echo "SQL \"ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS ''${BKPLOC}/controlfile.trc'' REUSE\";" >> ${RMANSCRIPT}
echo "SQL \"CREATE PFILE=''${BKPLOC}/init${ORACLE_SID}.ora'' FROM SPFILE\";" >> ${RMANSCRIPT}
echo "}" >> ${RMANSCRIPT}
echo "RMAN BACKUP SCRIPT CREATED."
echo 
sleep 1
echo "Backup Location is: ${BKPLOC}"
echo
sleep 1
echo "Starting Up RMAN Backup Job ..."
echo
sleep 1
echo "#!/bin/bash" > ${RMANSCRIPTRUNNER}
echo "nohup ${ORACLE_HOME}/bin/rman target / cmdfile=${RMANSCRIPT} | tee ${RMANLOG}  2>&1 &" >> ${RMANSCRIPTRUNNER}
chmod 740 ${RMANSCRIPTRUNNER}
source ${RMANSCRIPTRUNNER}
echo
echo " The RMAN backup job is currently running in the background. Disconnecting the current session will NOT interrupt the backup job :-)"
echo " Now, viewing the backup job log:"
echo
echo "Backup Location is: ${BKPLOC}"
echo "Check the LOGFILE: ${RMANLOG}"
echo

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
