# #################################################################################################
# [VER 1.4]
# This Script deletes Applied Archives older than Specified N hours on STANDBY DATABASE
# This script will run by default against ALL running STANDBY DATABASES.
# Please read the following instructions on how to use this script:
# - You can set MAIL_LIST variable to your E-mail to receive an email alert if archives
#   are not applied.
#	e.g. MAIL_LIST="john.smith@abc.com"
# - You can specify the candidate archives for deletion older than N hours by setting
#   LAST_N_HOURS variable to the number of hours.
#	e.g. Deleting applied archives in older than 24 hours
#	LAST_N_HOURS=24
# - You can EXCLUDE any instance from having the script to run against by passing INSTANCE_NAME
#   to EXL_DB variable.
#	e.g. excluding orcl from archive deletion:
#	EXL_DB="\-MGMTDB|ASM|orcl"
# - You can use FORCE option when deleting the archives from RMAN console: [Y|N]
#       e.g. FORCE_DELETION=Y
# - You can decide to CROSSCHECK the archivelogs after the archivelogs deletion: [Y|N]
#       e.g. VALIDATE_ARCHIVES=Y
#
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# 				    #   #   # #   #  
# Created:      14-Nov-2016
# Modified:	11-Jan-2017	Added more information to the output.
#		17-Jan-2017	Added the capability of turning ON/OFF the options of 
#				FORCE deletion of the archives and CROSSCHECK after the deletion.
#		20-Jul-2017	Neutralized login.sql if found under Oracle User Home Directory.
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
# #################################################################################################

# ##################################
# VARIABLES: [To be ALTERED By User] .......................................
# ##################################

SCRIPT_NAME="delete_standby_archives.sh"
SRV_NAME=`uname -n`
MAIL_LIST="youremail@yourcompany.com"

# #############################################################################
# Define the number of HOURS where ARCHIVES older than N Hours will be deleted: [Default 8 HOURS]
# #############################################################################
LAST_N_HOURS=8
export LAST_N_HOURS

# #############################################################################
# Do you want to CROSSCHECK the ARCHIVELOGS after the deletion?: [Y|N]		[Default YES]
# #############################################################################
VALIDATE_ARCHIVES=Y

# #############################################################################
# Do you want to FORCEFULLY DELETE the ARCHIVELOGS?: [Y|N]			[Default NO]
# #############################################################################
FORCE_DELETION=N

# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"				#Excluded INSTANCES [Will not get reported offline].


# ##############################
# SCRIPT ENGINE STARTS FROM HERE ............................................
# ##############################

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
#echo "ORACLE_SID is ${ORACLE_SID}"
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

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# #########################
# Variables:
# #########################
export PATH=$PATH:${ORACLE_HOME}/bin


# #########################
# LOG FILE:
# #########################
export LOG_DIR=`pwd`

        if [ ! -d ${LOG_DIR} ]
         then
          export LOG_DIR=/tmp
        fi
LOG_FILE=${LOG_DIR}/DELETE_ARCHIVES.log


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

# ###########################
# CHECKING DB ROLE: [STANDBY]
# ###########################
VAL12=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select COUNT(*) from v\$database where DATABASE_ROLE='PHYSICAL STANDBY';
exit;
EOF
)

DB_ROLE=`echo $VAL12| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`

# If the database is a standby DB, proceed with the rest of script:

		if [ ${DB_ROLE} -gt 0 ]
		 then
# Delete archives only when they are applied:
VAL31=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
--select count(*) from v\$archived_log where completion_time between sysdate-2 and  sysdate-$LAST_N_HOURS/24 and APPLIED = 'NO';
--select count(*) from v\$archived_log where name is not null and completion_time between sysdate and sysdate-$LAST_N_HOURS/24 and FAL='NO' and APPLIED = 'NO';
select count(*) from v\$archived_log where name is not null and completion_time between sysdate-(${LAST_N_HOURS}+1)/24 and  sysdate-({$LAST_N_HOURS})/24 and FAL='NO' and APPLIED = 'NO';
EOF
)
NO_APPL_ARC=`echo ${VAL31}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`
export NO_APPL_ARC

#echo "NOT_APPLIED_ARCHIVES=$NO_APPL_ARC"

if [ ${NO_APPL_ARC} -gt 0 ]
then
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
spool ${LOG_FILE}
PROMPT
PROMPT ------------------------------------------------------------------------------------------------

PROMPT SCRIPT TERMINATED! There are archivelogs in the last ${LAST_N_HOURS} Hours are NOT yet APPLIED.
PROMPT MAKE SURE THAT ALL ARCHIVES ARE APPLIED BEFORE DELETING ARCHIVELOGS.
PROMPT ------------------------------------------------------------------------------------------------

PROMPT THE FOLLOWING ARCHIVES ARE NOT YET APPLIED TO THE STANDBY DB:
PROMPT -------------------------------------------------------------

set pages 2000
set linesize 199
col name for a120
select name,to_char(completion_time,'HH24:MI:SS DD-MON-YYYY') completion_time,applied from v\$archived_log
where name is not null and completion_time <= sysdate-${LAST_N_HOURS}/24 and FAL='NO' and APPLIED = 'NO'
order by completion_time asc;

PROMPT
spool off
EOF

mail -s "ALERT: ARCHIVES IN THE LAST [${LAST_N_HOURS}] HOURS ARE NOT APPLIED ON STANDBY DB [${DB_NAME}] " ${MAIL_LIST} < ${LOG_FILE}

else

echo ""
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo "ALL Archives in the last ${LAST_N_HOURS} Hours were APPLIED successfully."
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo ""
VAL35=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
PROMPT
--select count(*) from v\$archived_log where name is not null and completion_time between sysdate-2 and sysdate-${LAST_N_HOURS}/24 and APPLIED = 'YES';
select count(*) from v\$archived_log where name is not null and completion_time <= sysdate-${LAST_N_HOURS}/24 and APPLIED = 'YES';
EOF
)
CAND_DEL_ARC=`echo ${VAL35}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`
export CAND_DEL_ARC
  if [ ${CAND_DEL_ARC} -gt 0 ]
   then
echo "CHECKING CANDIDATE ARCHIVES FOR DELETION ..."
sleep 1
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
PROMPT THE FOLLOWING CANDIDATE ARCHIVES WILL BE DELETED:
PROMPT -------------------------------------------------

col name for a120
select name from v\$archived_log where name is not null and FAL='NO' and completion_time <= sysdate-${LAST_N_HOURS}/24;
EOF

# CHECK CROSSCHECK OPTION:

	case ${VALIDATE_ARCHIVES} in
	y|Y|yes|YES|Yes) CROSSCHECK_ARCHIVELOGS="change archivelog all crosscheck;"; export CROSSCHECK_ARCHIVELOGS;;
        *)		 CROSSCHECK_ARCHIVELOGS=""; export CROSSCHECK_ARCHIVELOGS;;
        esac

# CHECK FORCE DELETION OPTION:

        case ${FORCE_DELETION} in
        y|Y|yes|YES|Yes) FORCE_OPTION="force"; export FORCE_OPTION;;
        *)               FORCE_OPTION=""; export FORCE_OPTION;;
        esac

# START CANDIDATE ARCHIVES DELETION FROM RMAN CONSOLE:
export NLS_DATE_FORMAT="DD-MON-YY HH24:MI:SS"
${ORACLE_HOME}/bin/rman target / <<EOF
delete noprompt ${FORCE_OPTION} archivelog all completed before 'sysdate-${LAST_N_HOURS}/24';
${CROSSCHECK_ARCHIVELOGS}
EOF
echo ""
echo "ALL ARCHIVES OLDER THAN ${LAST_N_HOURS} HOURS WERE DELETED SUCCESSFULLY."
echo "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
echo ""
   else
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT
PROMPT AVAILABLE ARCHIVES STATUS IN THE LAST ${LAST_N_HOURS} HOURS:
PROMPT -----------------------------------------------

set pages 2000 linesize 199
col name for a120
select name,to_char(completion_time,'DD-MON-YYYY HH24:MI:SS') completion_time,applied from v\$archived_log
where name is not null and completion_time >= sysdate-${LAST_N_HOURS}/24
order by completion_time asc;
EOF
echo ""
echo "NO CANDIDATE ARCHIVES ARE ELIGIBLE FOR DELETION IN THE LAST ${LAST_N_HOURS} HOURS !"
echo "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
echo ""
  fi
fi
		fi
		                if [ ${DB_ROLE} -eq 0 ]
                 		 then
		 		  echo "Database ${DB_NAME} is NOT a STANDBY DB"
		 		  echo "This script is designed to run against STANDBY DBs ONLY!"
		 		  echo "SCRIPT TERMINATED!"
				fi
done

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
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
