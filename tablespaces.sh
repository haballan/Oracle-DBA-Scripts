# ###################################################################
# VER [3.3]
# Checking ASM Diskgroups, FRA and Tablespaces Size	  
#				    #   #     #
# Author:	Mahmmoud ADEL	  # # # #  #####
# Created:	18-12-13	#   #   # #    #  
#
# Modified:	04-04-16	dba_tablespace_usage_metrics view
#				will be used for 11g onwards versions
#				for checking tablespaces size
#				As advised by: Satyajit Mohapatra
#		02-01-17	Added FRA size check.
#		
#
# ###################################################################
SCRIPT_NAME="tablespaces"

# ###########
# Description:
# ###########
echo
echo "========================================================================="
echo "This script Checks ASM Diskgroups, FRA & TABLESPACES Size on the database ..."
echo "========================================================================="
echo
sleep 1

# ###############
# SCRIPT SETTINGS:
# ###############
# Allow the script to use the legacy tablespace size calculation in case some tablespaces are NOT presented in dba_tablespace_usage_metrics:
# Although enabling this setting will make sure all tablespaces will be listed, the legacy calculation method is NOT ACCURATE!
SUPPORT_LEGACY=N
export SUPPORT_LEGACY


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

# Neutralize login.sql file:
# Existance of login.sql file under Oracle user Linux home directory eliminates many functions during the execution of this script from crontab:

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# ###################
# Getting DB Version:
# ###################

VAL311=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select version from v\$instance;
exit;
EOF
)
DB_VER=`echo $VAL311|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# #####################
# Getting DB Block Size:
# #####################
VAL312=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select value from v\$parameter where name='db_block_size';
exit;
EOF
)
blksize=`echo $VAL312|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# #####################
# Getting DB ROLE:
# #####################
VAL312=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select DATABASE_ROLE from v\$database;
exit;
EOF
)
DB_ROLE=`echo $VAL312|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

        case ${DB_ROLE} in
         PRIMARY) DB_ROLE_ID=0;;
               *) DB_ROLE_ID=1;;
        esac

# #####################
# Checking ASM Disks:
# #####################
VAL314=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from v\$asm_diskgroup;
exit;
EOF
)
ASM_GROUP_COUNT=`echo $VAL314|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# If ASM DISKS Are Exist, View their Size Details:
        if [ ${ASM_GROUP_COUNT} -gt 0 ]
         then
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF

set pages 100 lines 180 feedback off
col name for a35
PROMPT -----------------

prompt ASM DISK GROUPS:
PROMPT -----------------

select name,total_mb,free_mb,ROUND((1-(free_mb / total_mb))*100, 2) "%FULL" from v\$asm_diskgroup;
exit;
EOF
        fi

# ######################################
# Check Flash Recovery Area Utilization:
# ######################################
VAL318=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select value from v\$parameter where name='db_recovery_file_dest';
exit;
EOF
)
FRA_LOC=`echo ${VAL318}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# If FRA is configured, check the its utilization:
  if [ ! -z ${FRA_LOC} ]
   then

${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 100 lines 180 feedback off
col name for a30
col TOTAL_MB for 99999999999999999
col FREE_MB for  99999999999999999
PROMPT
PROMPT -----------------

PROMPT FRA Utilization:
PROMPT -----------------

SELECT NAME,SPACE_LIMIT/1024/1024 TOTAL_MB,(SPACE_LIMIT - SPACE_USED + SPACE_RECLAIMABLE)/1024/1024 AS FREE_MB,
ROUND((SPACE_USED - SPACE_RECLAIMABLE)/SPACE_LIMIT * 100, 1) AS "%FULL"
FROM V\$RECOVERY_FILE_DEST;

PROMPT
PROMPT ----------------

PROMPT FRA COMPONENTS:
PROMPT ----------------

select * from v\$flash_recovery_area_usage;
EOF

  fi

# #########################
# Tablespaces Size Check:
# #########################
case ${SUPPORT_LEGACY} in
Y|y|Yes|YES)
# Check if all tablespaces are presented in dba_tablespace_usage_metrics:
DBA_TABLESPACES_COUNT_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from dba_tablespaces;
exit;
EOF
)
DBA_TABLESPACES_COUNT=`echo ${DBA_TABLESPACES_COUNT_RAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

DBA_METRIC_COUNT_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from dba_tablespace_usage_metrics;
exit;
EOF
)
DBA_METRIC_COUNT=`echo ${DBA_METRIC_COUNT_RAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# If There is missing tablespaces inside dba_tablespace_usage_metrics then use the legacy way in calculating tablespaces size:
# Note: This problem happens for newly created tablespaces and for tablespaces having all their datafiles in AUTOEXTEND OFF mode.
  if [ ${DBA_TABLESPACES_COUNT} -gt ${DBA_METRIC_COUNT} ]
   then
	export DB_VER=9
  fi
esac

        if [ ${DB_VER} -gt 10 ] && [ ${DB_ROLE_ID} -eq 0 ]
         then
# If The Database Version is 11g Onwards and it's NOT in a STANDBY role:
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF

set pages 100 lines 180 feedback off
col tablespace_name for A25
col Total_MB for 999999999999
col Used_MB for 999999999999
col '%Used' for 999.99
comp sum of Total_MB on report
comp sum of Used_MB   on report
bre on report
PROMPT
PROMPT ------------------

prompt Tablespaces Size:
PROMPT ------------------

select tablespace_name,
       (tablespace_size*${blksize})/(1024*1024) Total_MB,
       (used_space*${blksize})/(1024*1024) Used_MB,
       used_percent "%Used"
from dba_tablespace_usage_metrics;
prompt
exit;
EOF

	 else

# If The Database Version is 10g Backwards:
# Check if AUTOEXTEND OFF (MAXSIZE=0) is set for any of the datafiles divide by ALLOCATED size else divide by MAXSIZE:
VAL33=$(${ORACLE_HOME}/bin/sqlplus -S '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_DATA_FILES WHERE MAXBYTES=0;
EOF
)
VAL44=`echo $VAL33| awk '{print $NF}'`
                case ${VAL44} in
                "0") CALCPERCENTAGE1="((sbytes - fbytes)*100 / MAXSIZE) bused " ;;
                  *) CALCPERCENTAGE1="round(((sbytes - fbytes) / sbytes) * 100,2) bused " ;;
                esac

VAL55=$(${ORACLE_HOME}/bin/sqlplus -S '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_TEMP_FILES WHERE MAXBYTES=0;
EOF
)
VAL66=`echo $VAL55| awk '{print $NF}'`
                case ${VAL66} in
                "0") CALCPERCENTAGE2="((sbytes - fbytes)*100 / MAXSIZE) bused " ;;
                  *) CALCPERCENTAGE2="round(((sbytes - fbytes) / sbytes) * 100,2) bused " ;;
                esac

${ORACLE_HOME}/bin/sqlplus -S '/ as sysdba' << EOF
set pages 100 lines 180 feedback off
col tablespace for A25
col "MAXSIZE MB" format 999999999
col x for 999999999 heading 'Allocated MB'
col y for 999999999 heading 'Free MB'
col z for 999999999 heading 'Used MB'
col bused for 999.99 heading '%Used'
comp sum of x on report
comp sum of y on report
comp sum of z on report
bre on report
select a.tablespace_name tablespace,bb.MAXSIZE/1024/1024 "MAXSIZE MB",sbytes/1024/1024 x,fbytes/1024/1024 y,
(sbytes - fbytes)/1024/1024 z,
$CALCPERCENTAGE1
from (select tablespace_name,sum(bytes) sbytes from dba_data_files group by tablespace_name ) a,
     (select tablespace_name,sum(bytes) fbytes,count(*) ext from dba_free_space group by tablespace_name) b,
     (select tablespace_name,sum(MAXBYTES) MAXSIZE from dba_data_files group by tablespace_name) bb
--where a.tablespace_name in (select tablespace_name from dba_tablespaces)
where a.tablespace_name = b.tablespace_name (+)
and a.tablespace_name = bb.tablespace_name
and round(((sbytes - fbytes) / sbytes) * 100,2) > 0
UNION ALL
select c.tablespace_name tablespace,dd.MAXSIZE/1024/1024 MAXSIZE_GB,sbytes/1024/1024 x,fbytes/1024/1024 y,
(sbytes - fbytes)/1024/1024 obytes,
$CALCPERCENTAGE2
from (select tablespace_name,sum(bytes) sbytes
      from dba_temp_files group by tablespace_name having tablespace_name in (select tablespace_name from dba_tablespaces)) c,
     (select tablespace_name,sum(bytes_free) fbytes,count(*) ext from v\$temp_space_header group by tablespace_name) d,
     (select tablespace_name,sum(MAXBYTES) MAXSIZE from dba_temp_files group by tablespace_name) dd
--where c.tablespace_name in (select tablespace_name from dba_tablespaces)
where c.tablespace_name = d.tablespace_name (+)
and c.tablespace_name = dd.tablespace_name
order by tablespace;

set feed off
set pages 0
-- 100% used tablespaces will not appear in dba_free_space, The following is to eliminate this BUG:
select 'ALARM: TABLESPACE '||tablespace_name||' IS 100% FULL !' from dba_data_files minus select 'ALARM: TABLESPACE '||tablespace_name||' IS 100% FULL !' from dba_free_space;
prompt 
EOF
	fi


# De-Neutralize login.sql file:
# If login.sql was renamed during the execution of the script revert it back to its original name:
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
