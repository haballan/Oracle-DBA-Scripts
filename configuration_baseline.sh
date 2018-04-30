# #############################################################################################################
# Ver [2.1]
# CONFIGURATION BASELINE COLLECTOR SCRIPT FOR ORACLE DATABASE & LINUX OS
# THIS SCRIPT WILL WRITE FOUR LOG FILES:
#	- ONE FOR DATABASE CONFIGURATIONS [One log for EACH database].
#	- ONE CONTAINS CREATION/GRANTED PRIVILEGES DDL STATEMENTS FOR ALL DB USERS [One log for EACH database].
#	- ONE FOR CONTROLFILE BACKUP TO TRACE  [One log for EACH database].
#	- ONE FOR OS CONFIGURATIONS.
#
# FEATURES:
# ^^^^^^^^
# - DATABASE Configuration Baseline: [For each database]
#	- Gather Instances & Database general info.
#	- Gather NON-DEFAULT Intialization Parameters.
#	- Gather DATABASE ENABLED FEATURES.
#	- Gather DATABASE FEATURES USAGE HISTORY.
#	- Gather DATABASE SETTINGS [Default tablespaces, Characterset, ...]
#	- Gather SERVICES details.
#	- Gather CLUSTERWARE INTERCONNECT details.
#	- Gather PATHCING history.
#	- Gather DATABASE LINKS.
#	- Gather DIRECTORIES info.
#	- Gather ACLs.
#	- Gather AUDIT settings.
#	- Gather USERS AND PROFILES details.
#	- Gather NUMBER OF OBJECTS in each schema.
#	- Gather the SIZE of each schema.
#	- Gather the biggest 100 objects [DB wide].
#	- Gather PRIVILEGED USERS details.
#	- Gather DATABASE PHYSICAL STRUCTURE information:
#		- CONTROLFILES.
#		- REDOLOG FILES AND GROUPS.
#		- TABLESPACES AND DATAFILES [+Utilization].
#		- ASM DISK GROUPS AND ASM FILES [+Utilization].
#		- FLASH RECOVERY AREA DETAILS [+Utilization].
#	- Gather RMAN NON-DEFAULT CONFIGURATIONS.
#	- Gather ACTVIE INCIDENTS information.
#	- Gather OUTSTANDING BUILT-IN ALERTS.
#	- Gather SCHEDULED JOBS details.
#	- Gather AUTOTASK MAINTENANCE WINDOW details.
#	- Gather ADVISORS STATUS.
#	- Gather HARDWARE STATISTICS details.
#	- Gather RECYCLEBIN information.
#	- Gather FLASHBACK RESTORE POINTS details.
#       - Gather FORIEGN KEY COLUMNS HAVING NO INDEXES information.
#       - Gather DISABLED CONSTRAINTS details.
#       - Gather MONITORED INDEXES details.
#       - Gather COMPRESSED TABLES details.
#       - Gather PARTITIONED TABLES details.
#       - Gather BLOCK CHANGE TRACKING details.
#	- Gather DB USERS CREATION/GRANTED PRIVILEGES DDL STATEMENT.
#
# - OPERATING SYSTEM Configuration Baseline:
#	- Gather RUNNING DATABASES & LISTENERS names.
#	- Gather LISTENERS STATUS details.
#       - Gather SERVER NAME AND OS/KERNEL VERSION information.
#       - Gather BOOT CONFIGURATIONS.
#	- Gather CLUSTERWARE CONFIGURATIONS.
#       - Gather ORACLE FILES details:
#		- oratab
#		- listener.ora
#		- tnsnames.ora
#		- sqlnet.ora
#       - Gather INSTALLED OPATCH PATCHES details.
#       - Gather FILESYSTEM details.
#       - Gather FILSYSTEM configurations.
#		- LOCAL FILESYSTEM.
#		- NFS SHARES.
#		- RAW DEVICES.
#		- MULTIPATH CONFIGURATIONS.
#		- ORACLE ASM CONFIGURATIONS.
#       - Gather USERS AND GROUPS details.
#       - Gather ACCOUNTS SETTINGS details.
#       - Gather USERS RESOURCES LIMITS details.
#       - Gather ORACLE USER CRONTAB JOBS details.
#       - Gather ORACLE USER PROFILE.
#       - Gather GENERIC/bashrc PROFILE.
#       - Gather SECURITY CONFIGURATIONS:
#		- FIREWALL RULES. [hashed]
#       	- PAM configurations.
#		- LOGINS default configurations.
#		- SELINUX configurations.
#		- INTRO MESSAGE.
#       - Gather SERVICES CONFIGURATIONS.
#       - Gather KERNEL PARAMETERS SETTINGS.
#       - Gather NETWORK CONFIGURATIONS:
#		- GENERAL NETWORK SETTINGS.
#		- DNS SETTINGS.
#		- NICS CONFIGURATIONS.
#		- NICS BONDING ALIASES.
#		- LOCAL/ALLOWED/DENIED HOSTS SETTINGS.
#       - Gather TIME AND DATE CONFIGURATIONS:
#		- LOCAL TIME CONFIGURATIONS.
#		- NTP STATUS & SETTINGS.
#       - Gather LOGGING SETTINGS:
#		- SYSLOG SETTINGS.
#		- KEEP LOG SETTINGS.
#		- LOG ROTATE SETTINGS.
#       - Gather HARDWARE INFORMATION:
#		- ALL ATTCHED HARDWARES.
#		- ATTCHED PCI DEVICES.
#		- CPU details.
#		- MEMORY details.
#       - Gather INSTALLED PACKAGES information.
#
# ^^^^^^^^
# CAUTION:
# ^^^^^^^^
# THIS SCRIPT MAY CAUSE A SLIGHT PERFORMANCE OVERHEAD WHEN IT RUNS,
# IT'S RECOMMENDED TO RUN IT DURING NON PEAK HOURS.
#
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# 				    #   #   # #   #  
#
# Created:      22-11-16 
# Modifications:
#		13-12-16	Added the biggest 100 objects. "Advised by: Farrukh Salman"
#		23-12-16	New feature added to gather clusterware configurations
#		27-12-16	New feature added to gather Oracle Restart configurations
#		17-05-17	Adjusted the Display settings (PAGES/LINESIZE)
#		13-08-17	Added SCAN/SCAN Listeners details.
#		07-09-17	Added OBJECTS WITH NON-DEFAULT DEGREE OF PARALLELISM.
#				"Query quoted from Tanel Poder blog: blog.tanelpoder.com"
#		14-12-17	Gather DB USERS CREATION/GRANTED PRIVILEGES DDL STATEMENT.
#		09-01-18 	Workaround for df command bug "`/root/.gvfs': Permission denied"
#
#
#
#
#
#
#
#
# 
# #############################################################################################################

SCRIPT_NAME="CONFIGURATION_BASELINE.sh"
SRV_NAME=`uname -n`
MAIL_LIST="youremail@yourcompany.com"


# ###############################
# ENABLE/DISABLE OPTIONS SECTION: 
# ###############################

# Send Configuration Baseline by Email Option: [Y|N]
MAIL_CONFBASE=Y

# Collect configuration baseline for DATABASES ONLY | DON'T collect OS baseline: [Y|N]
DB_CONFBASE_ONLY=N

# Collect DDL Creation Statements + Granted Privileges & Roles for ALL DB Users: [Y|N]
COLLECT_DBUSERS_DDL=Y

# CHECK CLUSTERWARE CONFIGURATIONS:
CLUSTER_CHECK=Y

                 case ${DB_CONFBASE_ONLY} in
                 y|Y|yes|YES|Yes)
		 echo ""
		 echo -e "\033[33;5mThe Configuration Baseline is getting collected for DATABASES ONLY...\033[0m"
		 echo "" ;;
		 *)
		 echo ""
		 echo -e "\033[33;5mThe Configuration Baseline is getting collected...\033[0m"
		 echo "" ;;
                 esac

# Check if MAIL_LIST parameter was set:
        	case ${MAIL_LIST} in
		"youremail@yourcompany.com")
         	echo ". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . "
         	echo "The Configuration Baseline will be saved in the current directory but will NOT be sent by E-mail."
                echo "In order to receive the report by email, please EDIT line# 140 by replacing youremail@yourcompany.com with your E-mail address."
                echo ". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . "
		echo ""
        	esac



# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"                           #Excluded INSTANCES [Will not get reported offline].


# ######################################
# Check the number of running instances:
# ######################################
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )

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
exit
fi

# #########################
# Variables:
# #########################
export LOGDATE=`date +%d-%b-%y`
export PATH=$PATH:${ORACLE_HOME}/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export LOG_DIR=`pwd`

        if [ ! -d ${LOG_DIR} ]
         then
          export LOG_DIR=/tmp
        fi

export DB_BASELINE=${LOG_DIR}/${ORACLE_SID}_ConfigurationBaseline_${LOGDATE}.log
export OS_BASELINE=${LOG_DIR}/${SRV_NAME}_ConfigurationBaseline_${LOGDATE}.log

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

# ###################
# Checking DB Version:
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


# ############################################
# Populating Database Configuration Baseline:
# ############################################

if [ ${INS_COUNT} -gt 0 ]
 then
VAL611=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize 160 pages 300
spool ${DB_BASELINE}

PROMPT #################################### ########

PROMPT CONFIGURATION BASELINE FOR DATABASE: ${ORACLE_SID}
PROMPT #################################### ########

PROMPT [COLLECTED ON: ${LOGDATE}]
PROMPT 
PROMPT -----------------------------

PROMPT Database General Information:
PROMPT -----------------------------

PROMPT
PROMPT INSTANCE INFO:
PROMPT ^^^^^^^^^^^^^

col INST_ID for 9999999
col inst_name for a20
col host_name for a30
col BLOCKED for a7
col STARTUP_TIME for a19
select INST_ID,instance_name INS_NAME,STATUS,DATABASE_STATUS DB_STATUS,VERSION,INSTANCE_ROLE,LOGINS,BLOCKED,to_char(STARTUP_TIME,'DD-MON-YY HH24:MI:SS') STARTUP_TIME from gv\$instance;

PROMPT
PROMPT DATABASE INFO:
PROMPT ^^^^^^^^^^^^^

col name for a8
col DB_UNIQUE_NAME for a14
col FLASHBACK for a9
col CURRENT_SCN for 9999999999999999999
col "LOG_MODE | FORCE" for a18
col "PLATFORM_NAME | ID" for a23
col created for a9
col RESETLOGS_TIME for a15

select DBID,NAME, DB_UNIQUE_NAME, DATABASE_ROLE, PROTECTION_MODE, to_char(CREATED,'DD-MON-YY') CREATED, PLATFORM_NAME||' | '||PLATFORM_ID "PLATFORM_NAME | ID", LOG_MODE||' | '||FORCE_LOGGING "LOG_MODE | FORCE", FLASHBACK_ON FLASHBACK,OPEN_MODE, LAST_OPEN_INCARNATION# LAST_INCR#, to_char(RESETLOGS_TIME,'DD-MON-YY HH24:MI') RESETLOGS_TIME,CURRENT_SCN from v\$DATABASE;

PROMPT
PROMPT INSTANCE NON-DEFAULT PARAMETERS:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

col INST_ID for 9999999
col "PARAMETER_VALUE" for a130
select  INST_ID,NAME||'='''||VALUE||'''' "PARAMETER_VALUE"
from    gv\$parameter
where   ISDEFAULT='FALSE'
order   by INST_ID,NAME;

PROMPT
PROMPT DATABASE ENABLED FEATURES:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^

col PARAMETER for a45
col value for a100
select * from v\$option order by 2,1;

PROMPT
PROMPT DATABASE FEATURES USAGE HISTORY:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

col name for a65
select NAME,FIRST_USAGE_DATE,LAST_USAGE_DATE,DETECTED_USAGES,AUX_COUNT,ERROR_COUNT from SYS.wri\$_dbu_feature_usage order by 3,2;  

PROMPT
PROMPT DATABASE SETTINGS:
PROMPT ^^^^^^^^^^^^^^^^^

col PROPERTY_NAME for a45
col PROPERTY_VALUE for a100
select PROPERTY_NAME,PROPERTY_VALUE from database_properties order by 1;

col PRODUCT for a60
col VERSION for a20
select PRODUCT,VERSION from product_component_version;

PROMPT
PROMPT BLOCK CHANGE TRACKING:
PROMPT ^^^^^^^^^^^^^^^^^^^^^

col FILENAME for a80
select * from v\$block_change_tracking;

PROMPT
PROMPT ALL SERVICES: [DBA_SERVICES]
PROMPT ^^^^^^^^^^^^^

col SERVICE_NAME for a30
col NETWORK_NAME for a40
col FAILOVER_METHOD for a15
col FAILOVER_TYPE for a15
col ENABLED for a7
col CLB_GOAL for a8

select NAME SERVICE_NAME, NETWORK_NAME, ENABLED, FAILOVER_METHOD, FAILOVER_TYPE, GOAL, CLB_GOAL, to_char(CREATION_DATE,'DD-MON-YY') CREATED, AQ_HA_NOTIFICATIONS from dba_services order by 1;


PROMPT
PROMPT CLUSTERWARE INTERCONNECT: [GV\$CLUSTER_INTERCONNECTS]
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^

select * from SYS.GV\$CLUSTER_INTERCONNECTS;

PROMPT
PROMPT PATCHING HISTORY: [DBA_REGISTRY_HISTORY]
PROMPT ^^^^^^^^^^^^^^^^

col ACTION_TIME for a19
col "ACTION | COMMENT" for a80
col VERSION for a12
select to_char(ACTION_TIME,'DD-MON-YY HH24:MI:SS') ACTION_TIME, ACTION||' | '||COMMENTS "ACTION | COMMENT", VERSION from dba_registry_history;

PROMPT
PROMPT DATABASE LINKS:
PROMPT ---------------

col "OWNER | TARGET_USER" for a45
col DB_LINK for a24
col host for a60
col created format A19 Heading "created"
select 	OWNER||' | '||USERNAME "OWNER | TARGET_USER",
	DB_LINK,
	HOST,
	to_char(CREATED,'MM/DD/YYYY HH24:MI:SS') created
from  	dba_db_links
order	by OWNER,DB_LINK;


PROMPT
PROMPT DIRECTORIES:
PROMPT ------------

col owner for a30
col DIRECTORY_NAME for a35
col DIRECTORY_PATH for a85
select OWNER,DIRECTORY_NAME,DIRECTORY_PATH from DBA_DIRECTORIES;


PROMPT
PROMPT ========================================================================================================

PROMPT

PROMPT -------------------

PROMPT SECURITY SETTINGS:
PROMPT -------------------

PROMPT
PROMPT ACLS:
PROMPT -----

SET lines 160
col host for a35
col ACL for a30
col PRINCIPAL for a15
col ACLID for a35
col start_date for a19
col end_date for a19
col ACL_OWNER for a30
col PRIVILEGE for a20
select * from dba_network_acls;
SELECT * FROM dba_network_acl_privileges;
 
PROMPT
PROMPT AUDIT SETTINGS:
PROMPT --------------

PROMPT
PROMPT AUDITED SYSTEM PRIVILEGES:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^

Select user_name,PRIVILEGE,success,failure from DBA_PRIV_AUDIT_OPTS order by 1,2;

PROMPT
PROMPT AUDITED OBJECT PRIVILEGES:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^

col "OWNER.OBJECT_NAME" for a30
select OWNER||'.'||OBJECT_NAME "OWNER.OBJECT_NAME",OBJECT_TYPE,ALT,AUD,COM,DEL,GRA,IND,INS,LOC,REN,SEL,UPD,REF,EXE,CRE,REA,WRI,FBK from DBA_OBJ_AUDIT_OPTS order by 1;

PROMPT
PROMPT FINE GRAINED AUDITING SETTINGS:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Select POLICY_NAME,ENABLED,OBJECT_SCHEMA,OBJECT_NAME,POLICY_COLUMN from DBA_AUDIT_POLICIES;


PROMPT
PROMPT ========================================================================================================

PROMPT

PROMPT --------------------

PROMPT USERS AND PROFILES:
PROMPT --------------------

PROMPT
PROMPT USERS:
PROMPT ^^^^^

set lines 160 pages 300
col USERNAME for a21
col ACCOUNT_STATUS for a20
col EXPIRY_DATE for a11
col LOCK_DATE for a11
col PROFILE for a15
col "CREATE_DATE | PASS_LAST_CHANGE" for a28
col "DEFAULT | TEMPORARY TABLESPACE" for a25
col hash for a16
col LIMIT for a30
select u.USERNAME,u.ACCOUNT_STATUS,u.PROFILE,u.DEFAULT_TABLESPACE||' | '||u.TEMPORARY_TABLESPACE "DEFAULT | TEMPORARY TABLESPACE",to_char(u.EXPIRY_DATE,'DD-MON-YY')EXPIRY_DATE,to_char(u.LOCK_DATE,'DD-MON-YY')LOCK_DATE,s.PASSWORD HASH,
to_char(CTIME,'DD-MON-YY') ||' | '||to_char(s.PTIME,'DD-MON-YY') "CREATE_DATE | PASS_LAST_CHANGE"
from sys.dba_users u, sys.user\$ s where u.username=s.name order by 1;

PROMPT
PROMPT PROFILES:
PROMPT ^^^^^^^^

col PROFILE for a35
select * from dba_profiles order by profile,resource_name;


PROMPT 
PROMPT NUMBER OF OBJECTS IN EACH SCHEMA:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

col USERNAME for a25
select 	USERNAME,
	count(decode(o.TYPE#, 2,o.OBJ#,'')) Tables,
	count(decode(o.TYPE#, 1,o.OBJ#,'')) Indexes,
	count(decode(o.TYPE#, 5,o.OBJ#,'')) Syns,
	count(decode(o.TYPE#, 4,o.OBJ#,'')) Views,
	count(decode(o.TYPE#, 6,o.OBJ#,'')) Seqs,
	count(decode(o.TYPE#, 7,o.OBJ#,'')) Procs,
	count(decode(o.TYPE#, 8,o.OBJ#,'')) Funcs,
	count(decode(o.TYPE#, 9,o.OBJ#,'')) Pkgs,
	count(decode(o.TYPE#,12,o.OBJ#,'')) Trigs,
	count(decode(o.TYPE#,10,o.OBJ#,'')) Deps
from 	SYS.obj\$ o,
	SYS.dba_users u
where 	u.USER_ID = o.OWNER# (+)
group	by USERNAME
order	by USERNAME;

PROMPT 
PROMPT SCHEMAS SIZE:
PROMPT ^^^^^^^^^^^^

set pages 999
col "size MB" format 999,999,999
col "Objects" format 999,999,999
select	obj.owner "Owner"
,	obj_cnt "Objects"
,	decode(seg_size, NULL, 0, seg_size) "size MB"
from 	(select owner, count(*) obj_cnt from dba_objects group by owner) obj
,	(select owner, ceil(sum(bytes)/1024/1024) seg_size
	from dba_segments group by owner) seg
where 	obj.owner  = seg.owner(+)
order	by 3 desc ,2 desc, 1;

PROMPT 
PROMPT BIGGEST 100 OBJECTS:
PROMPT ^^^^^^^^^^^^^^^^^^^

col owner for a35
col tablespace_name format a35
col segment_name for a35
Select * from (select OWNER,SEGMENT_NAME,SEGMENT_TYPE,TABLESPACE_NAME,BYTES/1024/1024 SIZE_MB from dba_segments order by 5 desc)where rownum <101 order by SIZE_MB desc;

PROMPT
PROMPT -------------

PROMPT PERMISSIONS:
PROMPT -------------

PROMPT 
PROMPT SYSDBA USERS:
PROMPT ^^^^^^^^^^^^

select * from v\$pwfile_users;

PROMPT DBA USERS:
PROMPT ^^^^^^^^^

select GRANTEE,GRANTED_ROLE from dba_role_privs where granted_role='DBA' order by 1;

--PROMPT
--PROMPT USERS PERMISSIONS:
--PROMPT ^^^^^^^^^^^^^^^^^



PROMPT
PROMPT ========================================================================================================

PROMPT
PROMPT --------------------

PROMPT PHYSICAL STRUCTURE:
PROMPT --------------------

PROMPT
PROMPT --------------

PROMPT CONTORLFILES:
PROMPT --------------
 
col name for a120
select NAME from V\$CONTROLFILE;

PROMPT
PROMPT ------------

PROMPT LOGFILES:
PROMPT ------------
 
PROMPT REDOLOG GROUPS:
PROMPT ^^^^^^^^^^^^^^

select THREAD#,GROUP#,MEMBERS,BLOCKSIZE,BYTES/1024/1024"SIZE_MB" from v\$log order by THREAD#,GROUP#;

PROMPT
PROMPT REDOLOG GROUPS:
PROMPT ^^^^^^^^^^^^^^

col MEMBER for a120
select GROUP#,TYPE,MEMBER from v\$logfile order by GROUP#;

PROMPT
PROMPT ------------

PROMPT Tablespaces:
PROMPT ------------

col FORCE_LOGGING for a13
col EXTENT_MANAGEMENT for a12
col ALLOCATION_TYPE for a15
col SEG_SPACE_MANAG for a15
col BIGFILE for a7
col COMPRESSED for a10
col ENCRYPTED for a4

select TABLESPACE_NAME,BLOCK_SIZE,STATUS,CONTENTS,LOGGING,FORCE_LOGGING,EXTENT_MANAGEMENT,ALLOCATION_TYPE,SEGMENT_SPACE_MANAGEMENT SEG_SPACE_MANAG,BIGFILE,DEF_TAB_COMPRESSION COMPRESSED,ENCRYPTED from dba_tablespaces
order by TABLESPACE_NAME;

PROMPT
PROMPT DATAFILES:
PROMPT ^^^^^^^^^

col FILE_NAME for a90
select TABLESPACE_NAME,FILE_NAME,BYTES/1024/1024 SIZE_MB,MAXBYTES/1024/1024 MAXSIZE_MB,ONLINE_STATUS from dba_data_files order by 1;

PROMPT TABLESPACES UTILIZATION:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^

col tablespace_name for A25
col Total_MB for 999999999999
col Used_MB for 999999999999
col '%Used' for 999.99
comp sum of Total_MB on report
comp sum of Used_MB  on report
comp sum of FREE_MB  on report
bre on report
select tablespace_name,
       (tablespace_size*$blksize)/(1024*1024) Total_MB,
       (used_space*$blksize)/(1024*1024) Used_MB,
       used_percent "%Used"
from dba_tablespace_usage_metrics;


PROMPT ASM DISKGROUPS AND DISKFILES:
PROMPT ------------------------------

set lines 160
                col DISK_FILE_PATH for a40
                col DISK_GROUP_NAME for a15
                col DISK_FILE_NAME for a15
                col DISK_FILE_PATH for a35
		col fail_group for a12 
                col "PCT_USED%" for 999.99
                SELECT NVL(a.name, '[CANDIDATE]')      disk_group_name
                --, b.HEADER_STATUS
		, a.type  REDUNDANCY
		, a.state MOUNT_STAT
                --, b.MOUNT_STATUS
                , b.STATE
                , b.path                disk_file_path
                , b.name              	disk_file_name
                , b.failgroup       	fail_group
                ,b.TOTAL_MB, b.COLD_USED_MB, b.FREE_MB, b.COLD_USED_MB*100/b.TOTAL_MB "PCT_USED%"
                FROM v\$asm_diskgroup a RIGHT OUTER JOIN v\$asm_disk b USING (group_number) ORDER BY a.name, b.path;


PROMPT
PROMPT FRA_SIZE:
PROMPT ---------

col name for a25
SELECT NAME,NUMBER_OF_FILES,SPACE_LIMIT/1024/1024/1024 AS TOTAL_SIZE_GB,SPACE_USED/1024/1024/1024 SPACE_USED_GB,
SPACE_RECLAIMABLE/1024/1024/1024 SPACE_RECLAIMABLE_GB,ROUND((SPACE_USED-SPACE_RECLAIMABLE)/SPACE_LIMIT * 100, 1) AS "%FULL_AFTER_CLAIM",
ROUND((SPACE_USED)/SPACE_LIMIT * 100, 1) AS "%FULL_NOW" FROM V\$RECOVERY_FILE_DEST;

PROMPT FRA_COMPONENTS:
PROMPT ---------------

select * from v\$flash_recovery_area_usage;


PROMPT
PROMPT ----------------------

PROMPT RMAN CONFIGURATIONS:
PROMPT ----------------------

col name for a45
col VALUE for a100
select name, value from v\$rman_configuration;

PROMPT
PROMPT ========================================================================================================

PROMPT
PROMPT ----------------------

PROMPT Active Incidents:
PROMPT ----------------------

set linesize 160
col PROBLEM_KEY for a65
select PROBLEM_KEY,to_char(FIRSTINC_TIME,'DD-MON-YY HH24:mi:ss') FIRST_OCCURENCE,to_char(LASTINC_TIME,'DD-MON-YY HH24:mi:ss')
LAST_OCCURENCE FROM V\$DIAG_PROBLEM;
PROMPT
PROMPT OUTSTANDING ALERTS:
PROMPT --------------------------

select * from DBA_OUTSTANDING_ALERTS;

PROMPT
PROMPT ========================================================================================================

PROMPT
PROMPT ------------------------------------

PROMPT SCHEDULED JOBS STATUS:
PROMPT ------------------------------------

PROMPT
PROMPT DBMS_JOBS:
PROMPT ----------

set linesize 160
col LAST_RUN for a25
col NEXT_RUN for a25
select job,schema_user,failures,to_char(LAST_DATE,'DD-Mon-YYYY hh24:mi:ss')LAST_RUN,to_char(NEXT_DATE,'DD-Mon-YYYY hh24:mi:ss')NEXT_RUN from dba_jobs;

PROMPT 
PROMPT DBMS_SCHEDULER:
PROMPT ---------------

col OWNER for a15
col JOB_NAME for a30
col STATE for a10
col FAILURE_COUNT for 9999 heading 'Fail'
col "DURATION(d:hh:mm:ss)" for a22
col REPEAT_INTERVAL for a75
col "LAST_RUN || REPEAT_INTERVAL" for a60
col "DURATION(d:hh:mm:ss)" for a12
--col LAST_START_DATE for a40
select OWNER,JOB_NAME,ENABLED,STATE,FAILURE_COUNT,to_char(LAST_START_DATE,'DD-Mon-YYYY hh24:mi:ss')||' || '||REPEAT_INTERVAL "LAST_RUN || REPEAT_INTERVAL",
extract(day from last_run_duration) ||':'||
lpad(extract(hour from last_run_duration),2,'0')||':'||
lpad(extract(minute from last_run_duration),2,'0')||':'||
lpad(round(extract(second from last_run_duration)),2,'0') "DURATION(d:hh:mm:ss)"
from dba_scheduler_jobs where JOB_NAME NOT LIKE 'AQ$_PLSQL_NTFN%' order by ENABLED,STATE;

PROMPT
PROMPT AUTOTASK INTERNAL MAINTENANCE WINDOWS:
PROMPT --------------------------------------

col WINDOW_NAME for a17
col NEXT_RUN for a20
col ACTIVE for a6
col OPTIMIZER_STATS for a15
col SEGMENT_ADVISOR for a15
col SQL_TUNE_ADVISOR for a16
col HEALTH_MONITOR for a15
SELECT WINDOW_NAME,TO_CHAR(WINDOW_NEXT_TIME,'DD-MM-YYYY HH24:MI:SS') NEXT_RUN,AUTOTASK_STATUS STATUS,WINDOW_ACTIVE ACTIVE,OPTIMIZER_STATS,SEGMENT_ADVISOR,SQL_TUNE_ADVISOR,HEALTH_MONITOR FROM DBA_AUTOTASK_WINDOW_CLIENTS;

PROMPT
PROMPT FAILED DBMS_SCHEDULER JOBS IN THE LAST 24H:
PROMPT -------------------------------------------

col LOG_DATE for a36
col OWNER for a15
col JOB_NAME for a35
col STATUS for a11
col RUN_DURATION for a20
col ID for 99
select INSTANCE_ID ID,JOB_NAME,OWNER,LOG_DATE,STATUS,ERROR#,RUN_DURATION from DBA_SCHEDULER_JOB_RUN_DETAILS where LOG_DATE > sysdate-1 and STATUS='FAILED' order by JOB_NAME,LOG_DATE;

PROMPT
PROMPT ========================================================================================================

PROMPT
PROMPT ------------------------------

PROMPT ADVISORS STATUS:
PROMPT ------------------------------

col CLIENT_NAME for a40
col window_group for a30
col STATUS for a15
col CONSUMER_GROUP for a25
SELECT client_name, status, consumer_group, window_group FROM dba_autotask_client ORDER BY client_name;

PROMPT
PROMPT ========================================================================================================

PROMPT
PROMPT --------------------------------------------------------

PROMPT CURRENT OS / HARDWARE STATISTICS:
PROMPT --------------------------------------------------------

col value for 99999999999999999999999
select stat_name,value from v\$osstat;

PROMPT
PROMPT ========================================================================================================

PROMPT
PROMPT
PROMPT --------------------------------

PROMPT RESOURCE LIMIT:
PROMPT --------------------------------

col INST_ID for 9999999
col INITIAL_ALLOCATION for a20
col LIMIT_VALUE for a20
select * from gv\$resource_limit order by RESOURCE_NAME;

PROMPT
PROMPT --------------------------------

PROMPT RECYCLEBIN OBJECTS#:
PROMPT --------------------------------

set feedback off
select count(*) "RECYCLED_OBJECTS#",sum(space)*$blksize/1024/1024 "TOTAL_SIZE_MB" from dba_recyclebin group by 1;
set feedback on
PROMPT
PROMPT [Note: Consider purging DBA_RECYCLEBIN for better performance]


PROMPT
PROMPT ------------------------------------------

PROMPT FLASHBACK RESTORE POINTS:
PROMPT ------------------------------------------

col TIME for a35
col RESTORE_POINT_TIME for a17
col "DATABASE_INCARNATION#" heading "DB_INCR#" for 99999999
col RESTORE_POINT_TIME for a18
select * from V\$RESTORE_POINT;


PROMPT
PROMPT ----------------------------------

PROMPT HEALTH MONITOR:
PROMPT ----------------------------------

select name,type,status,description,repair_script from V\$HM_RECOMMENDATION where time_detected > sysdate -1;


PROMPT
PROMPT ========================================================================================================

PROMPT
PROMPT
PROMPT -------------------

PROMPT OBJECTS HIGHLIGHTS:
PROMPT -------------------

PROMPT
PROMPT INVALID OBJECTS:
PROMPT ^^^^^^^^^^^^^^^

col SUBOBJECT_NAME for a30
col status for a15
col "OWNER.OBJECT_NAME" for a55
col LAST_DDL_TIME for a20
select OWNER||'.'||OBJECT_NAME "OWNER.OBJECT_NAME",SUBOBJECT_NAME,OBJECT_TYPE,status,to_char(LAST_DDL_TIME,'DD-MON-YY HH24:mi:ss') LAST_DDL_TIME from DBA_INVALID_OBJECTS;

PROMPT
PROMPT UNUSABLE INDEXES:
PROMPT ^^^^^^^^^^^^^^^^^

col INDEX_NAME for a50
col TABLE_NAME for a50
select owner||'.'||INDEX_NAME "INDEX_NAME",INDEX_TYPE,TABLE_OWNER||'.'||TABLE_NAME "TABLE_NAME",COMPRESSION,TABLESPACE_NAME from dba_indexes where status='UNUSABLE';


PROMPT
PROMPT FOREIGN KEY COLUMNS WITHOUT INDEXES:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

set linesize 160
col TABLE_NAME for a35
col CONSTRAINT_NAME for a35
col COLUMN_NAME for a22
select  acc.OWNER,
	acc.TABLE_NAME,
	acc.COLUMN_NAME,
        acc.CONSTRAINT_NAME,
        acc.POSITION,
        'No Index' Problem
from    dba_cons_columns acc, 
        dba_constraints ac
where   ac.CONSTRAINT_NAME = acc.CONSTRAINT_NAME
and     ac.CONSTRAINT_TYPE = 'R'
and     acc.OWNER not in ('SYS','SYSTEM','DBSNMP','EXFSYS','MDSYS','ORDDATA','PERFSTAT','STDBYPERF','APEX_050000','SYSMAN','ORDSYS','OLAPSYS')
and     not exists (
        select  'TRUE' 
        from    dba_ind_columns b
        where   b.TABLE_OWNER = acc.OWNER
        and     b.TABLE_NAME = acc.TABLE_NAME
        and     b.COLUMN_NAME = acc.COLUMN_NAME
        and     b.COLUMN_POSITION = acc.POSITION)
order   by acc.OWNER, acc.CONSTRAINT_NAME, acc.COLUMN_NAME, acc.POSITION;

PROMPT
PROMPT DISABLED CONSTRAINTS:
PROMPT ^^^^^^^^^^^^^^^^^^^^

column OWNER format A20 Heading "OWNER"
column TABLE_NAME format A35 Heading "TABLE_NAME"
column CONSTRAINT_NAME format A35 Heading "CONSTRAINT_NAME"
column STATUS format A12 Heading "STATUS"
column type format A20 Heading "type"
select  OWNER,
        TABLE_NAME,
        CONSTRAINT_NAME,
        decode(CONSTRAINT_TYPE, 'C','Check',
                                'P','Primary Key',
                                'U','Unique',
                                'R','Foreign Key',
                                'V','With Check Option') type,
        STATUS 
from    dba_constraints
where   STATUS = 'DISABLED' and OWNER <> 'SYSTEM'
order   by OWNER, TABLE_NAME, CONSTRAINT_NAME;


PROMPT
PROMPT Monitored INDEXES:
PROMPT ^^^^^^^^^^^^^^^^^

col Index_NAME for a40
col TABLE_NAME for a40
        select io.name Index_NAME, t.name TABLE_NAME,decode(bitand(i.flags, 65536),0,'NO','YES') Monitoring,
        decode(bitand(ou.flags, 1),0,'NO','YES') USED,ou.start_monitoring,ou.end_monitoring
        from sys.obj$ io,sys.obj$ t,sys.ind$ i,sys.object_usage ou where i.obj# = ou.obj# and io.obj# = ou.obj# and t.obj# = i.bo# order by 1;

PROMPT
PROMPT COMPRESSED TABLES:
PROMPT ^^^^^^^^^^^^^^^^^

SELECT OWNER,TABLE_NAME,TABLESPACE_NAME,COMPRESSION,COMPRESS_FOR FROM DBA_TABLES WHERE COMPRESSION='ENABLED' AND OWNER <> 'SYSMAN' ORDER BY OWNER;

PROMPT
PROMPT PARTITIONED TABLES:
PROMPT ^^^^^^^^^^^^^^^^^^

col table_name format a40
select	owner,table_name,DEF_TABLESPACE_NAME,partitioning_type,partition_count
from	dba_part_tables
where	owner not in ('SYS','SYSTEM','SYSMAN','SQLTXPLAIN')
order by owner;

PROMPT
PROMPT IOT TABLES:
PROMPT ^^^^^^^^^^

select owner,table_name,IOT_TYPE from dba_tables where IOT_TYPE='IOT' and owner not in ('SYS','EXFSYS','DBSNMP','WMSYS','CTXSYS','SYSMAN');

PROMPT
PROMPT OBJECTS WITH NON-DEFAULT DEGREE OF PARALLELISM: [Query from: http://blog.tanelpoder.com/?s=index+rebuild]
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

col DEGREE for a6
SELECT 'INDEX' OBJECT_TYPE, OWNER, INDEX_NAME, TRIM(DEGREE) DEGREE FROM DBA_INDEXES WHERE TRIM(DEGREE) > TO_CHAR(1)
UNION ALL
SELECT 'TABLE', OWNER, TABLE_NAME, TRIM(DEGREE) DEGREE FROM DBA_TABLES WHERE TRIM(DEGREE) > TO_CHAR(1)
order by 1,2;

/*
PROMPT
PROMPT OBJECTS WITH NOLOGGING OPTION:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

SELECT 'INDEX' OBJECT_TYPE, OWNER, INDEX_NAME, LOGGING FROM DBA_INDEXES WHERE LOGGING='NO'
and owner not in ('SYS','XDB','DBSNMP','SQLTXPLAIN','WMSYS','SYSTEM','MDSYS','EXFSYS')
UNION ALL
SELECT 'TABLE', OWNER, TABLE_NAME, LOGGING FROM DBA_TABLES WHERE LOGGING='NO'
and owner not in ('SYS','XDB','DBSNMP','SQLTXPLAIN','WMSYS','SYSMAN','SYSTEM','MDSYS','EXFSYS')
order by 1,2;
*/

PROMPT
PROMPT CORRUPTED BLOCKS:
PROMPT ^^^^^^^^^^^^^^^^

select * from V\$DATABASE_BLOCK_CORRUPTION;

PROMPT
PROMPT CONTROLFILE TRACE BACKUP:
PROMPT -------------------------

set feedback off
ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS '${LOG_DIR}/Controlfile_Trc_Bkp_${DB_NAME}.trc' REUSE;


spool off
exit;
EOF
)

FILE_NAME=${LOG_DIR}/Controlfile_Trc_Bkp_${DB_NAME}.trc
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${DB_BASELINE}
cat ${FILE_NAME}                                                        >> ${DB_BASELINE}
fi

                case ${COLLECT_DBUSERS_DDL} in
                y|Y|yes|YES|Yes)

export LOGDATE=`date +%d-%b-%y`
SPOOLLOF=${LOG_DIR}/List_Of_Users_${DB_NAME}_${LOGDATE}.log
SPOOL_FILE=${LOG_DIR}/ALL_USERS_DDL_${DB_NAME}_${LOGDATE}.log

echo "*****************" >  ${SPOOL_FILE}
echo "ALL DB USERS DLL: [Excluding ('SYS','SYSTEM','DBSNMP','EXFSYS','MDSYS','ORDDATA')]" >> ${SPOOL_FILE}
echo "*****************" >> ${SPOOL_FILE}
echo "" 		 >> ${SPOOL_FILE}

# Perpare the List of user to loop on:
VAL_LOOPUSERS=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT
spool ${SPOOLLOF}
set pages 0
set echo off heading off feedback off
-- Excluding System users:
select username from dba_users where username not in ('SYS','SYSTEM','DBSNMP','EXFSYS','MDSYS','ORDDATA') order by 1;
spool off
EOF
)

# Loop on each user with generating its DDL:
for USERNAME in `cat ${SPOOLLOF}`
do
export USERNAME

VAL_USERSDDL=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
spool ${SPOOL_FILE} APPEND
set termout off
set linesize 150
set pages 50000
set feedback off
set trim on
set echo off
col USERNAME for a30
col account_status for a23

PROMPT
PROMPT ======================================

PROMPT USER [${USERNAME}]
PROMPT ======================================

select a.username,a.account_status,a.profile,q.tablespace_name,q.bytes/1024/1024 USED_MB, q.max_bytes "MAX_QUOTA_Bytes" from dba_users a, dba_ts_quotas q where a.username=q.username and a.username='${USERNAME}';
set pages 0
set echo off heading off feedback off
-- Generate Creation Statement:
SELECT 'CREATE USER ' || u.username ||' IDENTIFIED ' ||' BY VALUES ''' || c.password || ''' DEFAULT TABLESPACE ' || u.default_tablespace ||' TEMPORARY TABLESPACE ' || u.temporary_tablespace ||' PROFILE ' || u.profile || case when account_status= 'OPEN' then ';' else ' Account LOCK;' end "--Creation Statement"
FROM dba_users u,user$ c where u.username=c.name and u.username=upper('${USERNAME}')
UNION
-- Generate Granted Roles:
select 'GRANT '||GRANTED_ROLE||' TO '||GRANTEE|| case when ADMIN_OPTION='YES' then ' WITH ADMIN OPTION;' else ';' end "Granted Roles"
from dba_role_privs where grantee= upper('${USERNAME}')
UNION
-- Generate System Privileges:
select 'GRANT '||PRIVILEGE||' TO '||GRANTEE|| case when ADMIN_OPTION='YES' then ' WITH ADMIN OPTION;' else ';' end "Granted System Privileges"
from dba_sys_privs where grantee= upper('${USERNAME}')
UNION
-- Generate Object Privileges:
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||case when GRANTABLE='YES' then ' WITH GRANT OPTION;' else ';' end "Granted Object Privileges"
from DBA_TAB_PRIVS where GRANTEE=upper('${USERNAME}');
spool off
EOF
)
done

echo ""									>> ${DB_BASELINE}
echo "--------------------------"					>> ${DB_BASELINE}
echo "ALL DB USERS DDL SAVED TO: ${SPOOL_FILE}"				>> ${DB_BASELINE}
echo "--------------------------"					>> ${DB_BASELINE}
echo ""									>> ${DB_BASELINE}
		esac

echo ""                                                                 >> ${DB_BASELINE}
echo "---------------------------------------"                          >> ${DB_BASELINE}
echo "END OF DATABASE CONFIGURATION BASELINE."                          >> ${DB_BASELINE}
echo "---------------------------------------"                          >> ${DB_BASELINE}
echo ""                                                                 >> ${DB_BASELINE}
echo "# REPORT BUGS to: mahmmoudadel@hotmail.com"                       >> ${DB_BASELINE}
echo "# EVERY MONTH A NEW VERSION OF DBA BUNDLE GET RELEASED, DOWNLOAD IT FROM:"                 >> ${DB_BASELINE}
echo "# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html"        >> ${DB_BASELINE}

                 case ${MAIL_CONFBASE} in
                 y|Y|yes|YES|Yes)
mail -s "CONFIGURATION BASELINE | DATABASE [${DB_NAME}] On Server [${SRV_NAME}]" $MAIL_LIST < ${DB_BASELINE};;
		 esac

echo "Configuration Baseline for DATABASE [${DB_NAME}]: ${DB_BASELINE}"

# End looping for databases:
fi
done


# Decide to go forward and collect OS configuration baseline or exit:
                 case ${DB_CONFBASE_ONLY} in
                 y|Y|yes|YES|Yes)
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
		 exit;;
                 esac

# ###############################################################
# OS CONFIGURATION BASELINE
# ###############################################################
echo "# ########################################################"  	>  ${OS_BASELINE}
echo "# OS Configuration Baseline" 				  	>> ${OS_BASELINE}
echo "# ########################################################" 	>> ${OS_BASELINE}
echo "[COLLECTED ON: ${LOGDATE}]"                                       >> ${OS_BASELINE}
echo ""								  	>> ${OS_BASELINE}
echo "============ ============================================="	>> ${OS_BASELINE}
echo "SERVER NAME: ${SRV_NAME}"						>> ${OS_BASELINE}
echo "============ ============================================="       >> ${OS_BASELINE}

FILE_NAME=/etc/oracle-release
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "OS Version:"                                                      >> ${OS_BASELINE}
echo "----------"                                                       >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
elif [ -f /etc/redhat-release ]
then
cat /etc/redhat-release                                                 >> ${OS_BASELINE}
fi

echo ""                                                                 >> ${OS_BASELINE}
echo "Uptime Info:"                                                     >> ${OS_BASELINE}
echo "-----------"                                                      >> ${OS_BASELINE}
uptime                                                                  >> ${OS_BASELINE}

echo ""                                                                 >> ${OS_BASELINE}
echo "Kernel Version:"                                                  >> ${OS_BASELINE}
echo "--------------"                                                   >> ${OS_BASELINE}
uname -a                                                                >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}

INST_COUNT=`/bin/ps -ef|grep pmon|grep -v grep |wc -l`
if [ ${INST_COUNT} -gt 0 ]
then
echo "RUNNING DATABASE INSTANCES:"                                      >> ${OS_BASELINE}
echo "--------------------------"                                       >> ${OS_BASELINE}
/bin/ps -ef|grep pmon|grep -v grep					>> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi
LISTENER_COUNT=`/bin/ps -ef|grep tnslsnr|grep -v grep|wc -l`
if [ ${LISTENER_COUNT} -gt 0 ]
then
echo "RUNNING LISTENERS:"                                               >> ${OS_BASELINE}
echo "------------------"                                               >> ${OS_BASELINE}
/bin/ps -ef|grep tnslsnr|grep -v grep 					>> ${OS_BASELINE}

#for LISTENER_NAME in $( ps -ef|grep -v grep|grep tnslsnr|awk 'NR==1{for (i=1;i<=NF;i++)if ($i=="-inherit"){n=i-1;m=NF-(i==NF)}} {for(i=1;i<=NF;i+=1+(i==n))printf "%s%s",$i,i==m?ORS:OFS}'|awk 'NR==1{for (i=1;i<=NF;i++)if ($i=="-no_crs_notify"){n=i-1;m=NF-(i==NF)}} {for(i=1;i<=NF;i+=1+(i==n))printf "%s%s",$i,i==m?ORS:OFS}'|awk '{print $NF}' )
for LISTENER_NAME in $( ps -ef|grep -v grep|grep tnslsnr|awk '{print $9}' )
 do
export LISTENER_NAME
#LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep -i ${LISTENER_NAME}|awk 'NR==1{for (i=1;i<=NF;i++)if ($i=="-inherit"){n=i-1;m=NF-(i==NF)}} {for(i=1;i<=NF;i+=1+(i==n))printf "%s%s",$i,i==m?ORS:OFS}'|awk 'NR==1{for (i=1;i<=NF;i++)if ($i=="-no_crs_notify"){n=i-1;m=NF-(i==NF)}} {for(i=1;i<=NF;i+=1+(i==n))printf "%s%s",$i,i==m?ORS:OFS}'|awk '{print $(NF-1)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"|head -1`
LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep -i ${LISTENER_NAME}|awk '{print $8}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"|head -1`
export LISTENER_HOME
TNS_ADMIN=${LISTENER_HOME}/network/admin; export TNS_ADMIN

# For DEBUGGING purpose:
#echo "Listener_name is: $LISTENER_NAME"
#echo "listener_home is: $LISTENER_HOME"
#echo "TNS_ADMIN is: $TNS_ADMIN"

FILE_NAME=${LISTENER_HOME}/bin/lsnrctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "LISTENER STATUS: [${LISTENER_NAME}]"                              >> ${OS_BASELINE}
echo "^^^^^^^^^^^^^^^"                                                  >> ${OS_BASELINE}
${LISTENER_HOME}/bin/lsnrctl status ${LISTENER_NAME}                    >> ${OS_BASELINE}
fi
done

fi


FILE_NAME=/etc/sysconfig/grub
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "Boot Configurations: ${FILE_NAME}"                                >> ${OS_BASELINE}
echo "-------------------"                                              >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

# Hashed STARTUP configurations to be run only by root user:
#FILE_NAME=/etc/inittab
#export FILE_NAME
#if [ -f ${FILE_NAME} ]
#then
#echo ""                                                                 >> ${OS_BASELINE}
#echo "Startup Configurations: ${FILE_NAME}"                             >> ${OS_BASELINE}
#echo "-------------------------------------"                            >> ${OS_BASELINE}
#cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
#fi

# ############################################
# Checking RAC/ORACLE_RESTART Services:
# ############################################

                case ${CLUSTER_CHECK} in
                y|Y|yes|YES|Yes)

# Check for ocssd clusterware process:
CHECK_OCSSD=`ps -ef|grep 'ocssd.bin'|grep -v grep|wc -l`
CHECK_CRSD=`ps -ef|grep 'crsd.bin'|grep -v grep|wc -l`

if [ ${CHECK_CRSD} -gt 0 ]
then
 CLS_STR=crs
 export CLS_STR
 CLUSTER_TYPE=CLUSTERWARE
 export CLUSTER_TYPE
else
 CLS_STR=has
 export CLS_STR
 CLUSTER_TYPE=ORACLE_RESTART
 export CLUSTER_TYPE
fi


    if [ ${CHECK_OCSSD} -gt 0 ]
     then

GRID_HOME=`ps -ef|grep 'ocssd.bin'|grep -v grep|awk '{print $NF}'|sed -e 's/\/bin\/ocssd.bin//g'|grep -v sed|grep -v "//g"`
export GRID_HOME

echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "${CLUSTER_TYPE} DETAILS"                                          >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}

FILE_NAME=${GRID_HOME}/bin/crsctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo "CLUSTER VERSION: crsctl query ${CLS_STR} softwareversion"         >> ${OS_BASELINE}
echo "---------------"                                                  >> ${OS_BASELINE}
$GRID_HOME/bin/crsctl query ${CLS_STR} softwareversion                  >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

	if [ ${CHECK_CRSD} -gt 0 ]
	then

GRID_HOME=`ps -ef|grep 'ocssd.bin'|grep -v grep|awk '{print $NF}'|sed -e 's/\/bin\/ocssd.bin//g'|grep -v sed|grep -v "//g"`
export GRID_HOME

FILE_NAME=${GRID_HOME}/bin/olsnodes
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "CLUSTER NAME: ${FILE_NAME} -c"                                    >> ${OS_BASELINE}
echo "------------"                                                     >> ${OS_BASELINE}
${GRID_HOME}/bin/olsnodes -c                                            >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "CLUSTER NODES: ${FILE_NAME} -n -s -t"                             >> ${OS_BASELINE}
echo "-------------"                                                    >> ${OS_BASELINE}
${GRID_HOME}/bin/olsnodes -n -s -t                                      >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi


FILE_NAME=${GRID_HOME}/bin/oifcfg
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "CLUSTER INTERCONNECT & PUBLIC IP NAME: oifcfg getif"              >> ${OS_BASELINE}
echo "-------------------------------------"                            >> ${OS_BASELINE}
${GRID_HOME}/bin/oifcfg getif                                           >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=${ORACLE_HOME}/bin/srvctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "CLUSTER SCAN IPs: srvctl config scan"                             >> ${OS_BASELINE}
echo "----------------"                                                 >> ${OS_BASELINE}
${ORACLE_HOME}/bin/srvctl config scan                                   >> ${OS_BASELINE}
fi

FILE_NAME=${ORACLE_HOME}/bin/srvctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "CLUSTER VIRTUAL IP NAME: srvctl config nodeapps"                  >> ${OS_BASELINE}
echo "-----------------------"                                          >> ${OS_BASELINE}
${ORACLE_HOME}/bin/srvctl config nodeapps                               >> ${OS_BASELINE}
fi

FILE_NAME=${ORACLE_HOME}/bin/srvctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "CLUSTER SCAN Listeners: srvctl config scan_listener"              >> ${OS_BASELINE}
echo "----------------------"                                           >> ${OS_BASELINE}
${ORACLE_HOME}/bin/srvctl config scan_listener                          >> ${OS_BASELINE}
fi

FILE_NAME=${ORACLE_HOME}/bin/srvctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "CLUSTER SCAN Listeners status: srvctl status scan_listener"       >> ${OS_BASELINE}
echo "-----------------------------"                                    >> ${OS_BASELINE}
${ORACLE_HOME}/bin/srvctl status scan_listener                          >> ${OS_BASELINE}
fi



FILE_NAME=${GRID_HOME}/bin/ocrcheck
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "^^^^^^^^^^"                                                       >> ${OS_BASELINE}
echo "OCR DISKS:"                                                       >> ${OS_BASELINE}
echo "^^^^^^^^^^"                                                       >> ${OS_BASELINE}
${GRID_HOME}/bin/ocrcheck                                               >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=${GRID_HOME}/bin/crsctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "^^^^^^^^^^^"                                                      >> ${OS_BASELINE}
echo "VOTE DISKS:"                                                      >> ${OS_BASELINE}
echo "^^^^^^^^^^^"                                                      >> ${OS_BASELINE}
${GRID_HOME}/bin/crsctl query css votedisk                              >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

	fi

FILE_NAME=${ORACLE_HOME}/bin/srvctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "ASM CONFIGURATIONS: srvctl config asm"                            >> ${OS_BASELINE}
echo "------------------"                                               >> ${OS_BASELINE}
${ORACLE_HOME}/bin/srvctl config asm                                    >> ${OS_BASELINE}
fi


FILE_NAME=${GRID_HOME}/bin/crsctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "CLUSTERWARE SERVICES: crsctl status resource"                     >> ${OS_BASELINE}
echo "---------------------"                                            >> ${OS_BASELINE}
AWK=/usr/bin/awk 
$AWK \
'BEGIN {printf "%-55s %-24s %-18s\n", "HA Resource", "Target", "State";
printf "%-55s %-24s %-18s\n", "-----------", "------", "-----";}'	>> ${OS_BASELINE}
$GRID_HOME/bin/crsctl status resource | $AWK \
'BEGIN { FS="="; state = 0; }
$1~/NAME/ && $2~/'$1'/ {appname = $2; state=1};
state == 0 {next;}
$1~/TARGET/ && state == 1 {apptarget = $2; state=2;}
$1~/STATE/ && state == 2 {appstate = $2; state=3;}
state == 3 {printf "%-55s %-24s %-18s\n", appname, apptarget, appstate; state=0;}'	>> ${OS_BASELINE}
fi 


# Clustered Databases Configurations:
FILE_NAME=${ORACLE_HOME}/bin/srvctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
# Loop for the clustered configured databases:
for CLUSTER_DB in $(${ORACLE_HOME}/bin/srvctl config database)
	do
export CLUSTER_DB
echo ""                                                                 >> ${OS_BASELINE}
echo "^^^^^^^^^^^^^^^^^^^"                                              >> ${OS_BASELINE}
echo "Database [${CLUSTER_DB}]"                                         >> ${OS_BASELINE}
echo "^^^^^^^^^^^^^^^^^^^"                                              >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "DATABASE CONFIGURATIONS: srvctl config database -d ${CLUSTER_DB}" >> ${OS_BASELINE}
echo "-----------------------"                                          >> ${OS_BASELINE}
${ORACLE_HOME}/bin/srvctl config database -d ${CLUSTER_DB}              >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "DATABASE SERVICES STATUS: srvctl status service -d ${CLUSTER_DB}" >> ${OS_BASELINE}
echo "------------------------"                                         >> ${OS_BASELINE}
${ORACLE_HOME}/bin/srvctl status service -d ${CLUSTER_DB}               >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "DATABASE SERVICES CONFIGURATIONS: srvctl config service"          >> ${OS_BASELINE}
echo "--------------------------------"                                 >> ${OS_BASELINE}
${ORACLE_HOME}/bin/srvctl config service -d ${CLUSTER_DB}               >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
	done
fi

FILE_NAME=${GRID_HOME}/crs/install/s_crsconfig_${SRV_NAME}_env.txt
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo "CLUSTERWARE NLS_LANG CONFIGURATIONS: ${FILE_NAME}"                >> ${OS_BASELINE}
echo "-----------------------------------"                              >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi


FILE_NAME=/etc/oracle/ocr.loc
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "OCR DISKS LOCATION: ${FILE_NAME}"                                 >> ${OS_BASELINE}
echo "-------------------"                                              >> ${OS_BASELINE}
cat /etc/oracle/ocr.loc                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

   fi
		;;
		esac


echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "ORACLE FILES"                                                     >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}

FILE_NAME=${ORATAB}
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "ORATAB: ${FILE_NAME}"                                             >> ${OS_BASELINE}
echo "------"                                                           >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

# Oracle Network Files:

#TNS_ADMIN=${ORACLE_HOME}/network/admin
#export TNS_ADMIN

FILE_NAME=${TNS_ADMIN}/listener.ora
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "LISTENER: ${FILE_NAME}"                                           >> ${OS_BASELINE}
echo "--------"                                                         >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=${TNS_ADMIN}/tnsnames.ora
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "TNSNAMES: ${FILE_NAME}"                                           >> ${OS_BASELINE}
echo "--------"                                                         >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=${TNS_ADMIN}/sqlnet.ora
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "SQLNET: ${FILE_NAME}"                                             >> ${OS_BASELINE}
echo "------"                                                           >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

# APPLIED PATCHES DETAILS:
FILE_NAME=${ORACLE_HOME}/OPatch/opatch
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "ORACLE PATCHES DETAILS: opatch lsinventory -details"              >> ${OS_BASELINE}
echo "-----------------------"                                          >> ${OS_BASELINE}
${ORACLE_HOME}/OPatch/opatch lsinventory -details                       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi


# Workaround df command output bug "`/root/.gvfs': Permission denied"
if [ -f /etc/redhat-release ]
 then
  export DF='df -hPx fuse.gvfs-fuse-daemon'
 else
  export DF='df -h'
fi

echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "FILESYSTEM Settings"                                              >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "df -h"                                                            >> ${OS_BASELINE}
echo "------"                                                           >> ${OS_BASELINE}
/bin/${DF}                                                              >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "mount Command:"                                                   >> ${OS_BASELINE}
echo "--------------"                                                   >> ${OS_BASELINE}
/bin/mount                                                              >> ${OS_BASELINE}

FILE_NAME=/etc/fstab
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "/etc/fstab"                                                       >> ${OS_BASELINE}
echo "----------"                                                       >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

FILE_NAME=/sbin/blkid
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "ASM DISKS MOUNT AND LABELS: ${FILE_NAME}"                         >> ${OS_BASELINE}
echo "--------------------------"                                       >> ${OS_BASELINE}
/sbin/blkid |sort -k 2 -t:|grep oracleasm                               >> ${OS_BASELINE}
fi

FILE_NAME=/etc/exports
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "NFS Shares: ${FILE_NAME}"                                         >> ${OS_BASELINE}
echo "----------"                                                       >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

FILE_NAME=/etc/sysconfig/rawdevices
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "RAW Devices: ${FILE_NAME}"                                        >> ${OS_BASELINE}
echo "------------"                                                     >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

FILE_NAME=/etc/multipath.conf
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "Multipath Configurations: ${FILE_NAME}"                           >> ${OS_BASELINE}
echo "-------------------------"                                        >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

FILE_NAME=/etc/sysconfig/oracleasm
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "Oracle ASM Configurations: ${FILE_NAME}"                          >> ${OS_BASELINE}
echo "--------------------------"                                       >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi



echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "USERS AND GROUPS"                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "Oracle Owner Configuration:"                                      >> ${OS_BASELINE}
echo "---------------------------"                                      >> ${OS_BASELINE}
/usr/bin/id ${ORA_USER}                                                 >> ${OS_BASELINE}
/usr/bin/id                                                             >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "ACCOUNT Settings:"                                                >> ${OS_BASELINE}
echo "................."                                                >> ${OS_BASELINE}
/usr/bin/chage -l ${ORA_USER}                                           >> ${OS_BASELINE}

echo ""                                                                 >> ${OS_BASELINE}
echo "RESOURCE Limits:"                                                 >> ${OS_BASELINE}
echo "................"                                                 >> ${OS_BASELINE}
ulimit -a                                                               >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}

echo ""                                                                 >> ${OS_BASELINE}
echo "CRONTAB Jobs:"                                                    >> ${OS_BASELINE}
echo "............."                                                    >> ${OS_BASELINE}
/usr/bin/crontab -l  2>/dev/null                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}

echo ""                                                                 >> ${OS_BASELINE}
echo "bash_profile:"                                                    >> ${OS_BASELINE}
echo "............."                                                    >> ${OS_BASELINE}
cat ~/.bash_profile                                                     >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}


FILE_NAME=/etc/passwd
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "USERS Configurations: ${FILE_NAME}"                               >> ${OS_BASELINE}
echo "---------------------"                                            >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

FILE_NAME=/etc/group
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "GROUPS Configurations: ${FILE_NAME}"                              >> ${OS_BASELINE}
echo "----------------------"                                           >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

FILE_NAME=/etc/security/limits.conf
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "USERS LIMITS Configurations: ${FILE_NAME}"                        >> ${OS_BASELINE}
echo "---------------------------"                                      >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

FILE_NAME=/etc/profile
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "GENERIC USERS PROFILE: ${FILE_NAME}"                              >> ${OS_BASELINE}
echo "----------------------"                                           >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

FILE_NAME=/etc/bashrc
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "GENERIC BASHRC PROFILE: ${FILE_NAME}"                             >> ${OS_BASELINE}
echo "----------------------"                                           >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi



echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "SECURITY Settings"                                                >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}

FILE_NAME=/etc/pam.d/system-auth
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "PAM Configurations: ${FILE_NAME}"                                 >> ${OS_BASELINE}
echo "-------------------"                                              >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

FILE_NAME=/etc/login.defs
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "LOGINS DEFAULT Configurations: ${FILE_NAME}"                      >> ${OS_BASELINE}
echo "------------------------------"                                   >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

# Hashed FIREWALL configurations to be run only by root user:
#FILE_NAME=/etc/sysconfig/iptables-config
#export FILE_NAME
#if [ -f ${FILE_NAME} ]
#then
#echo ""                                                                 >> ${OS_BASELINE}
#echo "FIREWALL Configurations: ${FILE_NAME}"                            >> ${OS_BASELINE}
#echo "-----------------------"                                          >> ${OS_BASELINE}
#cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
#fi

#FILE_NAME=/etc/sysconfig/iptables
#export FILE_NAME
#if [ -f ${FILE_NAME} ]
#then
#echo ""                                                                 >> ${OS_BASELINE}
#echo "FIREWALL RULES: ${FILE_NAME}"                                     >> ${OS_BASELINE}
#echo "--------------"                                                   >> ${OS_BASELINE}
#cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
#fi

FILE_NAME=/etc/sysconfig/selinux
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "SELINUX Configurations: ${FILE_NAME}"                             >> ${OS_BASELINE}
echo "-----------------------"                                          >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi

FILE_NAME=/etc/issue
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "INTRO Message Configuration: ${FILE_NAME}"                        >> ${OS_BASELINE}
echo "----------------------------"                                     >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi


echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "SERVICES Configurations"                                          >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}

#FILE_NAME=/sbin/service
#export FILE_NAME
#if [ -f ${FILE_NAME} ]
#then
#echo ""                                                                 >> ${OS_BASELINE}
#echo "RUNNING SERVICES: /sbin/service --status-all"                     >> ${OS_BASELINE}
#echo "-----------------"                                                >> ${OS_BASELINE}
#/sbin/service --status-all 2>/dev/null                                  >> ${OS_BASELINE}
#echo ""                                                                 >> ${OS_BASELINE}
#fi

FILE_NAME=/sbin/chkconfig
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
 if [ -f /etc/rc.d/init.d ]
  then
   echo ""                                                              >> ${OS_BASELINE}
   echo "SERVICES Settings: chkconfig --list"                           >> ${OS_BASELINE}
   echo "-----------------"                                             >> ${OS_BASELINE}
   /sbin/chkconfig --list|sort                                          >> ${OS_BASELINE}
   echo ""                                                              >> ${OS_BASELINE}
 fi
fi

echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "NETWORK Settings"                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}

FILE_NAME=/etc/sysconfig/network
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "GENERAL NETWORK Configurations: ${FILE_NAME}"                     >> ${OS_BASELINE}
echo "------------------------------"                                   >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/etc/resolv.conf
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "DNS Configurations: ${FILE_NAME}"                                 >> ${OS_BASELINE}
echo "------------------"                                               >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/sbin/ifconfig
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "NICs Configurations: ifconfig -a"                                 >> ${OS_BASELINE}
echo "--------------------"                                             >> ${OS_BASELINE}
/sbin/ifconfig -a                                                       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

echo "NICs Config Files:"                                               >> ${OS_BASELINE}
echo "------------------"                                               >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
for FILE_NAME in /etc/sysconfig/network-scripts/ifcfg-*
do
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo "cat ${FILE_NAME}"                                                >> ${OS_BASELINE}
echo "............................................."                   >> ${OS_BASELINE}
cat ${FILE_NAME}                                                       >> ${OS_BASELINE}
echo ""                                                                >> ${OS_BASELINE}
echo ""                                                                >> ${OS_BASELINE}
fi
done
echo ""                                                                >> ${OS_BASELINE}

FILE_NAME=/etc/modprobe.conf
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "NICs/BONDING ALIASES: ${FILE_NAME}"                               >> ${OS_BASELINE}
echo "--------------------"                                             >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/etc/hosts
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "${FILE_NAME} Configurations:"                                     >> ${OS_BASELINE}
echo "---------------------------"                                      >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/etc/hosts.allow
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "TCP WRAPPER: ALLOWED HOSTS: ${FILE_NAME}"                         >> ${OS_BASELINE}
echo "---------------------------"                                      >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/etc/hosts.deny
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "TCP WRAPPER: DENIED HOSTS: ${FILE_NAME}"                          >> ${OS_BASELINE}
echo "--------------------------"                                       >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/etc/mail/sendmail.mc
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "SMTP SERVER: ${FILE_NAME}"                                        >> ${OS_BASELINE}
echo "-----------"                                                      >> ${OS_BASELINE}
cat /etc/mail/sendmail.mc|grep SMART                                    >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi



echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "TIME AND DATE Configurations"                                     >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}

FILE_NAME=/etc/localtime
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "LOCAL TIME Configurations: ${FILE_NAME}"                          >> ${OS_BASELINE}
echo "-------------------------"                                        >> ${OS_BASELINE}
tail -1 ${FILE_NAME}                                                    >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/sbin/chkconfig
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "NTP SERVICE STATUS: chkconfig --list|grep ntp"                    >> ${OS_BASELINE}
echo "------------------"                                               >> ${OS_BASELINE}
/sbin/chkconfig --list|grep ntp                                         >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/etc/ntp.conf
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "NTP Configurations: ${FILE_NAME}"                                 >> ${OS_BASELINE}
echo "------------------"                                               >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/etc/sysconfig/ntpd
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "NTP Settings: ${FILE_NAME}"                                       >> ${OS_BASELINE}
echo "------------"                                                     >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi



echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "LOGGING Settings"                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}

FILE_NAME=/etc/sysconfig/syslog
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "SYSLOG Settings: ${FILE_NAME}"                                    >> ${OS_BASELINE}
echo "---------------"                                                  >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/etc/sysconfig/sysstat
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "KEEP LOG Settings: ${FILE_NAME}"                                  >> ${OS_BASELINE}
echo "-----------------"                                                >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/etc/logrotate.conf
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "ROTATE LOG Settings: ${FILE_NAME}"                                >> ${OS_BASELINE}
echo "-------------------"                                              >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi



echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "CURRENT RESOURCES INFORMATION"                                    >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}


FILE_NAME=/dev/mem
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "ALL HARDWARE DETAILS: dmidecode"                                  >> ${OS_BASELINE}
echo "---------------------"                                            >> ${OS_BASELINE}
/usr/sbin/dmidecode                                                     >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/sbin/lspci
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "PCI DEVICES DETAILS: lspci"                                       >> ${OS_BASELINE}
echo "-------------------"                                              >> ${OS_BASELINE}
/sbin/lspci                                                             >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/proc/cpuinfo
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "CPU DETAILS: ${FILE_NAME}"                                        >> ${OS_BASELINE}
echo "-----------"                                                      >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/proc/meminfo
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "MEMORY DETAILS: ${FILE_NAME}"                                     >> ${OS_BASELINE}
echo "--------------"                                                   >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo "KERNEL Settings"                                                  >> ${OS_BASELINE}
echo "=========================================================="       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}

FILE_NAME=/etc/sysctl.conf
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "Kernel NON-DEFAULT PARAMETERS: ${FILE_NAME}"                      >> ${OS_BASELINE}
echo "-----------------------------"                                    >> ${OS_BASELINE}
cat ${FILE_NAME}                                                        >> ${OS_BASELINE}
fi


FILE_NAME=/sbin/sysctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "ALL KERNEL PARAMETERS:"                                           >> ${OS_BASELINE}
echo "----------------------"                                           >> ${OS_BASELINE}
/sbin/sysctl -a 2>/dev/null                                             >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

FILE_NAME=/bin/rpm
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${OS_BASELINE}
echo "List Of ALL INSTALLED PACKAGES:"                                  >> ${OS_BASELINE}
echo "------------------------------"                                   >> ${OS_BASELINE}
/bin/rpm -qa|sort                                                       >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
fi

echo ""                                                                 >> ${OS_BASELINE}
echo "---------------------------------"                                >> ${OS_BASELINE}
echo "END OF OS CONFIGURATION BASELINE."                                >> ${OS_BASELINE}
echo "---------------------------------"                                >> ${OS_BASELINE}
echo ""                                                                 >> ${OS_BASELINE}
echo "# REPORT BUGS to: mahmmoudadel@hotmail.com"                       >> ${OS_BASELINE}
echo "# DOWNLOAD THE LATEST VERSION OF DBA BUNDLE FROM:"                >> ${OS_BASELINE}
echo "# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html"        >> ${OS_BASELINE}

                 case ${MAIL_CONFBASE} in
                 y|Y|yes|YES|Yes)
mail -s "CONFIGURATION BASELINE | SERVER [${SRV_NAME}]" ${MAIL_LIST} 	< ${OS_BASELINE};;
                 esac

echo "Configuration Baseline for OPERATING SYSTEM: ${OS_BASELINE}"
echo ""

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
