#!/bin/bash
# ####################################################################
# This script MUST run from the Primary DB server.
# It checks the LAG between Primary & Standby database
# To be run by ORACLE user		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	29-10-2015	    #   #   # #   # 
#			   
#
# ####################################################################

# #####################################
# Variables MUST be edited by the user: [Otherwise the script will not work]
# #####################################

# Here you replace youremail@yourcompany.com with your Email address:
EMAIL_RECEIVER="youremail@yourcompany.com"
export EMAIL_RECEIVER

# Replace ${ORACLE_SID} with the Primary DB instance SID:
ORACLE_SID=${ORACLE_SID}
export ORACLE_SID

# Replace STANDBY_TNS_ENTRY with the Standby Instance TNS entry you configured in the primary site tnsnames.ora file:
DRDBNAME=STANDBY_TNS_ENTRY
export DRDBNAME

# Replace ${ORACLE_HOME} with the ORACLE_HOME path on the primary server:
ORACLE_HOME=${ORACLE_HOME}
export ORACLE_HOME

# Log Directory Location:
LOG_DIR='/tmp'
export LOG_DIR

# Here you replace SYSPASS with user SYS password on the standby DB:
CRD='SYSPASS'
export CRD

# Replace "5" with the number of LAGGED ARCHIVELOGS if reached an Email alert will be sent to the receiver:
LAGTHRESHOLD=5
export LAGTHRESHOLD

# #############################################
# Other variables will be picked automatically:
# #############################################

SCRIPT_NAME="check_standby_lag.sh"
export SCRIPT_NAME

SRV_NAME=`uname -n`
export SRV_NAME

LNXVER=`cat /etc/redhat-release | grep -o '[0-9]'|head -1`
export LNXVER

MAIL_LIST="-r ${SRV_NAME} ${EMAIL_RECEIVER}"
export MAIL_LIST


# #########################################
# Script part to execute On the Primary:
# #########################################
# Check the current Redolog sequence number:
PRDBNAME_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
select name from v\$database;
exit;
EOF
)

PRDBNAME=`echo ${PRDBNAME_RAW} | awk '{print $NF}'`

PRSEQ_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
select max(sequence#) from v\$archived_log;  
exit;
EOF
)

PRSEQ=`echo ${PRSEQ_RAW} | awk '{print $NF}'`
export PRSEQ


# #########################################
# Script part to execute On the STANDBY:
# #########################################

# Get the last applied Archive Sequence number from the Standby DB:

DRSEQ_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
conn SYS/"${CRD}"@${DRDBNAME} AS SYSDBA
select max(sequence#) from v\$archived_log where applied='YES';
exit;
EOF
)

DRSEQ=`echo ${DRSEQ_RAW} | awk '{print $NF}'`
export DRSEQ

# Compare Both PRSEQ & DRSEQ to detect the lag:
# ############################################
LAG=$((${PRSEQ}-${DRSEQ}))
export LAG

	if [ ${LAG} -ge ${LAGTHRESHOLD} ]
		then
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize 1000 pages 100
spool ${LOG_DIR}/DR_LAST_APPLIED_SEQ.log
PROMPT Current Log Sequence on the Primary DB:
PROMPT ---------------------------------------------------------

archive log list

PROMPT
PROMPT Last Applied Log Sequence# on the Standby DB:
PROMPT -----------------------------------------------------------------

conn SYS/"${CRD}"@${DRDBNAME} AS SYSDBA
set linesize 1000 pages 100
select THREAD#,max(SEQUENCE#) from V\$ARCHIVED_LOG where APPLIED='YES' group by THREAD#;
exit;
EOF
# Send Email with LAG details:
mail -s "ALARM: DR DB [${DRDBNAME}] is LAGGING ${LAG} sequences behind Primary DB [${PRDBNAME}] on Server [${SRV_NAME}]" ${MAIL_LIST} < ${LOG_DIR}/DR_LAST_APPLIED_SEQ.log
        fi

echo
echo Primary DB Sequence is: ${PRSEQ}
echo Standby DB Sequence is: ${DRSEQ}
echo Number of Lagged Archives Between is: ${LAG}
echo

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
