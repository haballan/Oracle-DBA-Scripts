# #################################################################################
# Backup Controlfile & SPFILE & Generate AWR Report on ALL Running Databases
# #################################################################################
VER="[1.2]"
#
#
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      11-04-16            #   #   # #   #  
#
#		22-01-18 Added CONTROLFILE RMAN compressed backup.
#		23-01-18 Disabled the auto generation of AWR Report: AWRFLAG=N
#
#
#
# #################################################################################
SCRIPT_NAME="backup_ctrl_spf_AWR"
SRV_NAME=`uname -n`

# Receive an Email notification if the backup location filesystem hit the threshold:
MAIL_LIST="youremail@yourcompany.com"

# ###################
# SCRIPT CONTROLS:
# ###################

# Enable/Disable CONTROLFILE & SPFILE Backup: 	[Default ENABLED]
CTRLSPFFLAG=Y
export CTRLSPFFLAG

# Enable/Disable AWR Report Generation: 	[Default DISABLED]
AWRFLAG=N
export AWRFLAG

# #########################
# THRESHOLDS:
# #########################
# Don't run the backup if the Filesystem where the backup will be located has reached the following threshold:

FSTHRESHOLD=95          # FILESYSTEM %USED THRESHOLD IF THE BACKUP LOCATION REACHED THE SCRIPT WILL TERMINATE TO AVOID FILLING THE FILESYSTEM.

# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances dbalarm will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"     

# #########################
# Setting ORACLE_SID:
# #########################
# Exit with sending Alert mail if No DBs are running:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )
        if [ $INS_COUNT -eq 0 ]
         then
         exit
        fi

for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

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

# #########################
# Variables:
# #########################
export PATH=$PATH:${ORACLE_HOME}/bin

# ####################
# BACKUP DIRECTORY:
# ####################

# CONTORLFILE & SPFILE backup directory location:
BKP_DIR=${USR_ORA_HOME}/backup_ctl_spfile
export BKP_DIR

        if [ ! -d ${BKP_DIR} ]
         then
                mkdir -p ${BKP_DIR}
                chown -R ${ORA_USER} ${BKP_DIR}
                chmod -R go-rwx ${BKP_DIR}
        fi

	# Exit if the backup location is not accessible:
        if [ ! -d ${BKP_DIR} ]
         then
          	echo "Location Path \"${LOC1}\" is NOT EXIST!"
          	echo "Script Terminated!"
		exit
        fi

# AWR report directory location:
AWR_DIR=${BKP_DIR}/AWRs
export AWR_DIR

        if [ ! -d ${AWR_DIR} ]
         then
                mkdir -p ${AWR_DIR}
                chown -R ${ORA_USER} ${AWR_DIR}
                chmod -R go-rwx ${AWR_DIR}
        fi


# #######################################
# Checking The FILESYSTEM Available Size:
# #######################################

# Workaround df command output bug "`/root/.gvfs': Permission denied"
if [ -f /etc/redhat-release ]
 then
  export DF='df -hPx fuse.gvfs-fuse-daemon'
 else
  export DF='df -h'
fi

cd ${BKP_DIR}
FSLOG=/tmp/backup_ctl_spf_filesystem_used.log
echo "Reported By Script: ${SCRIPT_NAME}" 	> ${FSLOG}
echo "" 					>> ${FSLOG}
#echo "Controfile, SPFILE and AWR BACKUP has failed because the filesystem that hold the backup has hit the identified threshold ${FSTHRESHOLD}%" >> ${FSLOG}
echo "" 					>> ${FSLOG}
echo "Filesystem Utilization Details" 		>> ${FSLOG}
echo ".................................." 	>> ${FSLOG}
${DF} .						>> ${FSLOG}
${DF} .| grep -v "^Filesystem" |awk '{print substr($0, index($0, $2))}'| grep -v "/dev/mapper/"| grep -v "/dev/asm/"|awk '{print $(NF-1)" "$NF}'| while read OUTPUT
   do
        PRCUSED=`echo ${OUTPUT}|awk '{print $1}'|cut -d'%' -f1`
        FILESYS=`echo ${OUTPUT}|awk '{print $2}'`
		# Terminate the script and send notification to the user incase the THRESHOLD REACHED:
                if [ ${PRCUSED} -ge ${FSTHRESHOLD} ]
                 then
mail -s "WARNING: Controlfile/SPFILE/AWR Backup FAILED on Server [${SRV_NAME}] | Filesystem [${FILESYS}] has reached ${PRCUSED}% of USED space" ${MAIL_LIST} < ${FSLOG}
		 echo "Script Terminated! Please check the space on the backup location."
                fi
   done

LAST_PCTUSED=`cat ${FSLOG}|awk '{print $5}'|cut -d'%' -f1|tail -1`

                if [ ${LAST_PCTUSED} -ge ${FSTHRESHOLD} ]
                 then
                exit
                fi


rm -f ${FSLOG}


# ########################
# Getting ORACLE_BASE:
# ########################

# Get ORACLE_BASE from user's profile if it EMPTY:

if [ -z "${ORACLE_BASE}" ]
 then
  ORACLE_BASE=`grep -h 'ORACLE_BASE=\/' $USR_ORA_HOME/.bash* $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
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

     if [ -d $ORACLE_HOME/diagnostics/${DB_NAME_LOWER} ]
        then
                DB_NAME=$DB_NAME_LOWER
        else
                DB_NAME=$DB_NAME_UPPER
     fi

# ##################################
# Backup CONTROLFILE & SPFILE Script:
# ##################################
DATE_FORMAT=`date +"%d-This_Month-%Y"`
CONTROLFILE_BKP_NAME=${BKP_DIR}/CTRL_${DB_NAME}_${DATE_FORMAT}.trc
SPFILE_BKP_NAME=${BKP_DIR}/init${ORACLE_SID}_${DATE_FORMAT}.ora

# Check if the CONTROLFILE & SPFILE Backup flag is to Y:

                case ${CTRLSPFFLAG} in
                Y|y|YES|yes|Yes)

echo "Backing up CONTROLFILE & SPFILE on [${ORACLE_SID}] ..."
VAL1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
PROMPT Taking Controlfile Trace Backup ...
ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS '${CONTROLFILE_BKP_NAME}' REUSE;
PROMPT Taking SPFILE Text Backup ...
CREATE PFILE='${SPFILE_BKP_NAME}' FROM SPFILE;
-- Controlfile Physical Backup:
--ALTER DATABASE BACKUP CONTROLFILE TO '${BKP_DIR}/CTRL_${DB_NAME}_Physical.bkp' REUSE;
exit;
EOF
) 

VAL2=$(${ORACLE_HOME}/bin/rman target / << EOF
BACKUP AS COMPRESSED BACKUPSET CURRENT CONTROLFILE FORMAT '${BKP_DIR}/CONTROLFILE_%d_%I.bkp' REUSE ;
EOF
)

# Retain the backup taken on the FIRST day of each month:
        if [ ${DATE_FORMAT} = `date +"01-This_Month-%Y"` ]
         then
		DATE_FORMAT=`date +"%d-%m-%Y"`
		mv ${CONTROLFILE_BKP_NAME}   ${BKP_DIR}/CTRL_${DB_NAME}_${DATE_FORMAT}.trc
        fi

		esac
# ##################################
# AWR Report Generation Script:
# ##################################

# Define the AWR report period in days:
AWR_WINDOW=1

# Report Name:
LOGDATE=`date +%d-%m-%y`
REPORTNAME=${AWR_DIR}/AWR_${ORACLE_SID}_${LOGDATE}.html
export REPORTNAME

# Check if the AWR Report generation flag is to Y:

                case ${AWRFLAG} in
                Y|y|YES|yes|Yes)


echo "Generating AWR report on [${ORACLE_SID}] ..."
VAL3=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
DEFINE num_days=${AWR_WINDOW};
DEFINE i_instance=${ORACLE_SID};
DEFINE inst_name='${ORACLE_SID}';
DEFINE report_type='html';
DEFINE report_name='${REPORTNAME}';
DEFINE begin_snap=0;
DEFINE end_snap=0; 

column inst_name  heading "Instance Name" new_value inst_name format A16;
SELECT UPPER('&i_instance') inst_name FROM DUAL;

column begin_snap heading "Min SNAP ID"  new_value begin_snap format 9999999999;
column end_snap heading "Max SNAP ID"  new_value end_snap format 9999999999;

SELECT MIN(SNAP_ID) begin_snap FROM dba_hist_snapshot WHERE TRUNC(begin_interval_time) = TRUNC(SYSDATE-&num_days);
SELECT MAX(SNAP_ID) end_snap FROM dba_hist_snapshot WHERE TRUNC(begin_interval_time) = TRUNC(SYSDATE-&num_days);

--column report_name heading "AWR file name"  new_value report_name format A30; 
--SELECT '$REPORTNAME' report_name FROM DUAL; 

SELECT &num_days  i	num_days FROM DUAL;
SELECT '&report_type'   report_type FROM DUAL;
SELECT '$REPORTNAME'   	report_name FROM DUAL;
SELECT &begin_snap 	begin_snap FROM DUAL;
SELECT &end_snap 	end_snap  FROM DUAL;

@?/rdbms/admin/awrrpt.sql

undefine num_days;
undefine report_type;
undefine report_name;
undefine begin_snap;
undefine end_snap;
EOF
)

# Compress AWR reports:
gzip -f9 ${REPORTNAME}
                esac

   done

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
