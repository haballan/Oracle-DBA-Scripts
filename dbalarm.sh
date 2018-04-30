# #################################################################################################
# Checking DB & LISTENERS ALERTLOG FOR ERRORS.
# Report OFFLINE databases.
# Checking CPU, FILESYSTEM, TABLESPACES When exceed the THRESHOLD.
# Report Long running operations/Active sessions on DB when CPU goe beyond defined threshold.
# Checking BLOCKING SESSIONS ON THE DATABASE.
VER="[5.0]"
# #################################################################################################
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      22-12-13            #   #   # #   #  
#
# Modified:     23-12-13 Handled non exist logs 1run
#               14-05-14 Handled non existance of
#                        LOG_DIR directory.
#               18-05-14 Add Filsystem monitoring.
#               19-05-14 Add CPU monitoring.
#               03-12-14 Add Tablespaces monitoring
#               08-09-15 mpstat output change in Linux 6
#               02-04-16 Using dba_tablespace_usage_metrics To calculate MAXSIZE (11g onwards)
#                        Recommended by Satyajit Mohapatra.
#               10-04-16 Add Flash Recovery Area monitoring.
#               10-04-16 Add ASM Disk Groups monitoring.
#               15-09-16 Add "DIG MORE" feature to report.long running operations, queries
#                        and active sessions on DB side when CPU hits the pre-defined threshold.
#               29-12-16 Enhanced ORACLE_HOME search criteria.
#               02-01-17 Added EXL_DB parameter to allow the user to exclude DBs from having
#                        dbalarm script run against.
#               04-05-17 Added the ability to disable Database Down Alert
#                        through CHKOFFLINEDB variable.
#               11-05-17 Added the option to exclude tablespace/ASM Diskgroup from monitoring.
#               11-05-17 Tuned the method of reporting OFFLINE databases & checking listener log.
#               20-07-17 Modified COLUMNS env variable to fully display top command output.
#                        Neutralize login.sql if found in Oracle user home directory due to bugs.
#               19-10-17 Added the function of checking goldengate logfile.
#               11-04-18 Added the feature of monitoring the availability of specific service.
#		28-04-18 Added the function of printing the script progress.
#		30-04-18 Added Paranoid mode, to report EXPORT/IMPORT, ALTER SYSTEM, ALTER DATABASE 
#			 instance STARTUP/SHUTDOWN, other DB Major activities.
#
#
#
#
# #################################################################################################
SCRIPT_NAME="dbalarm${VER}"
SRV_NAME=`uname -n`
MAIL_LIST="youremail@yourcompany.com"

        case ${MAIL_LIST} in "youremail@yourcompany.com")
         echo
         echo "******************************************************************"
         echo "Buddy! You forgot to edit line# 47 in dbalarm.sh script."
         echo "Please replace youremail@yourcompany.com with your E-mail address."
         echo "******************************************************************"
         echo
         echo "Script Terminated !"
         echo 
         exit;;
        esac

FILE_NAME=/etc/redhat-release
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
LNXVER=`cat /etc/redhat-release | grep -o '[0-9]'|head -1`
export LNXVER
fi

# #########################
# THRESHOLDS:
# #########################
# Modify the THRESHOLDS to the value you prefer:

FSTHRESHOLD=95          # THRESHOLD FOR FILESYSTEM %USED [OS]
CPUTHRESHOLD=95         # THRESHOLD FOR CPU %UTILIZATION [OS]
TBSTHRESHOLD=95         # THRESHOLD FOR TABLESPACE %USED [DB]
FRATHRESHOLD=95         # THRESHOLD FOR FRA %USED        [DB]
ASMTHRESHOLD=95         # THRESHOLD FOR ASM DISK GROUPS  [DB]
BLOCKTHRESHOLD=1        # THRESHOLD FOR BLOCKED SESSIONS#[DB]
CHKLISTENER=Y           # Enable/Disable Checking Listeners: [Default Enabled]	[DB]
CHKOFFLINEDB=Y          # Enable/Disable Database Down Alert: [Default Enabled]	[DB]
CHKGOLDENGATE=N         # Enable/Disable Goldengate Alert: [Default Disabled]	[GG]
CPUDIGMORE=Y            # Break down to DB Active sessions when CPU hit the threshold: [RECOMMENDED TO SET =N on VERY BUSY environments]	[DB]
SERVICEMON=""           # Monitor Specific Named Services. e.g. SERVICEMON="'ORCL_RO','ERP_SRVC','SAP_SERVICE'"					[DB]
PARANOIDMODE=N          # Paranoid mode will report more events like export/import, instance shutdown/startup. [Default Disabled]		[DB]

# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances dbalarm will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"                   #Excluded INSTANCES [Will not get reported offline].

# #########################
# Excluded TABLESPACES:
# #########################
# Here you can exclude one or more tablespace if you don't want to be alerted when they hit the threshold:
# e.g. to exclude "UNDOTBS1" modify the following variable in this fashion without removing "donotremove" value:
# EXL_TBS="donotremove|UNDOTBS1"
EXL_TBS="donotremove"

# #########################
# Excluded ASM Diskgroups:
# #########################
# Here you can exclude one or more ASM Disk Groups if you don't want to be alerted when they hit the threshold:
# e.g. to exclude "FRA" DISKGROUP modify the following variable in this fashion without removing "donotremove" value:
# EXL_DISK_GROUP="donotremove|FRA"
EXL_DISK_GROUP="donotremove"

# #########################
# Excluded ERRORS:
# #########################
# Here you can exclude the errors that you don't want to be alerted when they appear in the logs:
# Use pipe "|" between each error.

EXL_ALERT_ERR="ORA-2396|TNS-00507|TNS-12502|TNS-12560|TNS-12537|TNS-00505"              #Excluded ALERTLOG ERRORS [Will not get reported].
EXL_LSNR_ERR="TNS-00507|TNS-12502|TNS-12560|TNS-12537|TNS-00505"                        #Excluded LISTENER ERRORS [Will not get reported].
EXL_GG_ERR="donotremove"                                                                #Excluded GoldenGate ERRORS [Will not get reported].

# ################################
# Excluded FILESYSTEM/MOUNT POINTS:
# ################################
# Here you can exclude specific filesystems/mount points from being reported by dbalarm:
# e.g. Excluding: /dev/mapper, /dev/asm mount points:

EXL_FS="\/dev\/mapper\/|\/dev\/asm\/"                                                   #Excluded mount points [Will be skipped during the check].

# Workaround df command output bug "`/root/.gvfs': Permission denied"
if [ -f /etc/redhat-release ]
 then
  export DF='df -hPx fuse.gvfs-fuse-daemon'
 else
  export DF='df -h'
fi

# #########################
# Checking The FILESYSTEM:
# #########################

echo "Checking FILESYSTEM Utilization ..."

# Report Partitions that reach the threshold of Used Space:

FSLOG=/tmp/filesystem_DBA_BUNDLE.log
echo "[Reported By ${SCRIPT_NAME} Script]"       > ${FSLOG}
echo ""                                         >> ${FSLOG}
${DF}                                           >> ${FSLOG}
${DF} | grep -v "^Filesystem" |awk '{print substr($0, index($0, $2))}'| egrep -v "${EXL_FS}"|awk '{print $(NF-1)" "$NF}'| while read OUTPUT
   do
        PRCUSED=`echo ${OUTPUT}|awk '{print $1}'|cut -d'%' -f1`
        FILESYS=`echo ${OUTPUT}|awk '{print $2}'`
                if [ ${PRCUSED} -ge ${FSTHRESHOLD} ]
                 then
mail -s "ALARM: Filesystem [${FILESYS}] on Server [${SRV_NAME}] has reached ${PRCUSED}% of USED space" $MAIL_LIST < ${FSLOG}
                fi
   done

rm -f ${FSLOG}


# #############################
# Checking The CPU Utilization:
# #############################

echo "Checking CPU Utilization ..."

# Report CPU Utilization if reach >= CPUTHRESHOLD:
OS_TYPE=`uname -s`
CPUUTLLOG=/tmp/CPULOG_DBA_BUNDLE.log

# Getting CPU utilization in last 5 seconds:
case `uname` in
        Linux ) CPU_REPORT_SECTIONS=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1 | grep ';' -o | wc -l`
                CPU_COUNT=`cat /proc/cpuinfo|grep processor|wc -l`
                        if [ ${CPU_REPORT_SECTIONS} -ge 6 ]; then
                           CPU_IDLE=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1| cut -d ";" -f 7`
                        else
                           CPU_IDLE=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1| cut -d ";" -f 6`
                        fi
        ;;
        AIX )   CPU_IDLE=`iostat -t $INTERVAL_SEC $NUM_REPORT | sed -e 's/,/./g'|tr -s ' ' ';' | tail -1 | cut -d ";" -f 6`
                CPU_COUNT=`lsdev -C|grep Process|wc -l`
        ;;
        SunOS ) CPU_IDLE=`iostat -c $INTERVAL_SEC $NUM_REPORT | tail -1 | awk '{ print $4 }'`
                CPU_COUNT=`psrinfo -v|grep "Status of processor"|wc -l`
        ;;
        HP-UX)  SAR="/usr/bin/sar"
                CPU_COUNT=`lsdev -C|grep Process|wc -l`
                if [ ! -x $SAR ]; then
                 echo "sar command is not supported on your environment | CPU Check ignored"; CPU_IDLE=99
                else
                 CPU_IDLE=`/usr/bin/sar 1 5 | grep Average | awk '{ print $5 }'`
                fi
        ;;
        *) echo "uname command is not supported on your environment | CPU Check ignored"; CPU_IDLE=99
        ;;
        esac

# Getting Utilized CPU (100-%IDLE):
CPU_UTL_FLOAT=`echo "scale=2; 100-($CPU_IDLE)"|bc`

# Convert the average from float number to integer:
CPU_UTL=${CPU_UTL_FLOAT%.*}

        if [ -z ${CPU_UTL} ]
         then
          CPU_UTL=1
        fi

# Compare the current CPU utilization with the Threshold:
CPULOG=/tmp/top_processes_DBA_BUNDLE.log

        if [ ${CPU_UTL} -ge ${CPUTHRESHOLD} ]
         then
                export COLUMNS=300           #Increase the COLUMNS width to display the full output [Default is 167]
                echo "CPU STATS:"         >  ${CPULOG}
                echo "========="          >> ${CPULOG}
                mpstat 1 5                >> ${CPULOG}
                echo ""                   >> ${CPULOG}
                echo "VMSTAT Output:"     >> ${CPULOG}
                echo "============="      >> ${CPULOG}
                echo "[If the runqueue number in the (r) column exceeds the number of CPUs [${CPU_COUNT}] this indicates a CPU bottleneck on the system]." >> ${CPULOG}
                echo ""                   >> ${CPULOG}
                vmstat 2 5                >> ${CPULOG}
                echo ""                   >> ${CPULOG}
                echo "Top 10 Processes:"  >> ${CPULOG}
                echo "================"   >> ${CPULOG}
                echo ""                   >> ${CPULOG}
                top -c -b -n 1|head -17   >> ${CPULOG}
                unset COLUMNS                #Set COLUMNS width back to the default value
                #ps -eo pcpu,pid,user,args | sort -k 1 -r | head -11 >> ${CPULOG}
# Check ACTIVE SESSIONS on DB side:
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

# Getting ORACLE_HOME:
# ###################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|egrep -v ${EXL_DB}|awk '{print $1}'|tail -1`
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


# Check Long Running Transactions if CPUDIGMORE=Y:
                 case ${CPUDIGMORE} in
                 y|Y|yes|YES|Yes)
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 200
SPOOL ${CPULOG} APPEND
prompt
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Prompt ACTIVE SESSIONS ON DATABASE [${ORACLE_SID}]:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

set feedback off linesize 200 pages 1000
col "OS_PID"                            for a8
col module                              for a30
col event                               for a24
col "STATUS|WAIT_STATE|TIME_WAITED"     for a31
col "INS|USER|SID,SER|MACHIN|MODUL"     for a65
col "ST|WA_ST|WAITD|ACT_SINC|LOG_T"     for a44
col "SQLID | FULL_SQL_TEXT"             for a75
col "CURR_SQLID"                        for a35
col "I|BLKD_BY"                         for a9
select
substr(s.INST_ID||'|'||s.USERNAME||'| '||s.sid||','||s.serial#||' |'||substr(s.MACHINE,1,22)||'|'||substr(s.MODULE,1,18),1,65)"INS|USER|SID,SER|MACHIN|MODUL"
,substr(s.status||'|'||w.state||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||to_char(LOGON_TIME,'ddMon'),1,44) "ST|WA_ST|WAITD|ACT_SINC|LOG_T"
,substr(w.event,1,24) "EVENT"
--substr(w.event,1,30)"EVENT",s.SQL_ID ||' | '|| Q.SQL_FULLTEXT "SQLID | FULL_SQL_TEXT"
,s.SQL_ID "CURRENT SQLID"
,s.FINAL_BLOCKING_INSTANCE||'|'||s.FINAL_BLOCKING_SESSION "I|BLKD_BY"
from    gv\$session s, gv\$session_wait w
where   s.USERNAME is not null
and     s.sid=w.sid
and     s.STATUS='ACTIVE'
and     w.EVENT NOT IN ('SQL*Net message from client','class slave wait','Streams AQ: waiting for messages in the queue','Streams capture: waiting for archive log'
        ,'Streams AQ: waiting for time management or cleanup tasks','PL/SQL lock timer','rdbms ipc message')
order by "I|BLKD_BY" desc,w.event,"INS|USER|SID,SER|MACHIN|MODUL","ST|WA_ST|WAITD|ACT_SINC|LOG_T" desc,"CURRENT SQLID";

PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT SESSIONS STATUS: [Local Instance]
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

set pages 0
select 'ALL:        '||count(*)         from v\$session;
select 'BACKGROUND: '||count(*)         from v\$session where USERNAME is null;
select 'INACTIVE:   '||count(*)         from v\$session where USERNAME is not null and status='INACTIVE';
select 'ACTIVE:     '||count(*)         from v\$session where USERNAME is not null and status='ACTIVE';

prompt
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Prompt Long Running Operations On Database [${ORACLE_SID}]:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

set linesize 200 pages 1000
col OPERATION                           for a21
col "%DONE"                             for 99.999
col "STARTED|MIN_ELAPSED|REMAIN"        for a30
col MESSAGE                             for a80
col "USERNAME| SID,SERIAL#"             for a26
        select USERNAME||'| '||SID||','||SERIAL# "USERNAME| SID,SERIAL#",SQL_ID
        --,OPNAME OPERATION
        ,substr(SOFAR/TOTALWORK*100,1,5) "%DONE"
        ,to_char(START_TIME,'DD-Mon HH24:MI')||'| '||trunc(ELAPSED_SECONDS/60)||'|'||trunc(TIME_REMAINING/60) "STARTED|MIN_ELAPSED|REMAIN" ,MESSAGE
        from v\$session_longops where SOFAR/TOTALWORK*100 <>'100'
        order by "STARTED|MIN_ELAPSED|REMAIN" desc, "USERNAME| SID,SERIAL#";

PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT Queries Running Since More Than 1 Hour On Database [${ORACLE_SID}]:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

set lines 200
col module                      for a30
col DURATION_HOURS              for 99999.9
col STARTED_AT                  for a13
col "USERNAME| SID,SERIAL#"     for a30
col "SQL_ID | SQL_TEXT"         for a120
select username||'| '||sid ||','|| serial# "USERNAME| SID,SERIAL#",substr(MODULE,1,30) "MODULE", to_char(sysdate-last_call_et/24/60/60,'DD-MON HH24:MI') STARTED_AT,
last_call_et/60/60 "DURATION_HOURS"
--,SQL_ID ||' | '|| (select SQL_FULLTEXT from v\$sql where address=sql_address) "SQL_ID | SQL_TEXT"
,SQL_ID
from v\$session where
username is not null 
and module is not null
-- 1 is the number of hours
and last_call_et > 60*60*1
and status = 'ACTIVE';

PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT RUNNING JOBS On Database [${ORACLE_SID}]:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

col INS                         for 999
col "JOB_NAME|OWNER|SPID|SID"   for a55
col ELAPSED_TIME                for a17
col CPU_USED                    for a17
col "WAIT_SEC"                  for 9999999999
col WAIT_CLASS                  for a15
col "BLKD_BY"                   for 9999999
col "WAITED|WCLASS|EVENT"       for a45
select j.RUNNING_INSTANCE INS,j.JOB_NAME ||' | '|| j.OWNER||' |'||SLAVE_OS_PROCESS_ID||'|'||j.SESSION_ID"JOB_NAME|OWNER|SPID|SID"
,s.FINAL_BLOCKING_SESSION "BLKD_BY",ELAPSED_TIME,CPU_USED
,substr(s.SECONDS_IN_WAIT||'|'||s.WAIT_CLASS||'|'||s.EVENT,1,45) "WAITED|WCLASS|EVENT",S.SQL_ID
from dba_scheduler_running_jobs j, gv\$session s
where   j.RUNNING_INSTANCE=S.INST_ID(+)
and     j.SESSION_ID=S.SID(+)
order by INS,"JOB_NAME|OWNER|SPID|SID",ELAPSED_TIME;

SPOOL OFF
EOF

                ;;
                esac
  done
mail -s "ALERT: CPU Utilization on Server [${SRV_NAME}] has reached [${CPU_UTL}%]" $MAIL_LIST < ${CPULOG}
        fi

rm -f ${CPUUTLLOG}
rm -f ${CPULOG}

echo "CPU CHECK Completed"

# #########################
# Getting ORACLE_SID:
# #########################
# Exit with sending Alert mail if No DBs are running:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )
        if [ $INS_COUNT -eq 0 ]
         then
         echo "[Reported By ${SCRIPT_NAME} Script]"                                              > /tmp/oracle_processes_DBA_BUNDLE.log
         echo " "                                                                               >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "Current running INSTANCES on server [${SRV_NAME}]:"                              >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "***************************************************"                             >> /tmp/oracle_processes_DBA_BUNDLE.log
         ps -ef|grep -v grep|grep pmon                                                          >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo " "                                                                               >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "Current running LISTENERS on server [${SRV_NAME}]:"                              >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "***************************************************"                             >> /tmp/oracle_processes_DBA_BUNDLE.log
         ps -ef|grep -v grep|grep tnslsnr                                                       >> /tmp/oracle_processes_DBA_BUNDLE.log
mail -s "ALARM: No Databases Are Running on Server: $SRV_NAME !!!" $MAIL_LIST                    < /tmp/oracle_processes_DBA_BUNDLE.log
         rm -f /tmp/oracle_processes_DBA_BUNDLE.log
         exit
        fi

# #########################
# Setting ORACLE_SID:
# #########################
echo "SETTING ORACLE_SID"
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

# #########################
# Getting ORACLE_HOME
# #########################
echo "Getting ORACLE HOME"
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
mail -s "dbalarm script on Server [${SRV_NAME}] failed to find ORACLE_HOME, Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory" $MAIL_LIST < /dev/null
exit
fi

# #########################
# Variables:
# #########################
export PATH=$PATH:${ORACLE_HOME}/bin
export LOG_DIR=${USR_ORA_HOME}/BUNDLE_Logs
mkdir -p ${LOG_DIR}
chown -R ${ORA_USER} ${LOG_DIR}
chmod -R go-rwx ${LOG_DIR}

        if [ ! -d ${LOG_DIR} ]
         then
          mkdir -p /tmp/BUNDLE_Logs
          export LOG_DIR=/tmp/BUNDLE_Logs
          chown -R ${ORA_USER} ${LOG_DIR}
          chmod -R go-rwx ${LOG_DIR}
        fi

# ##########################
# Neutralize login.sql file: [Bug Fix]
# ##########################
# Existance of login.sql file under Oracle user Linux home directory eliminates many functions during the execution of this script from crontab:
echo "Neutralizing login.sql if found"

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# ########################
# Getting ORACLE_BASE:
# ########################
echo "Getting ORACLE BASE"
# Get ORACLE_BASE from user's profile if it EMPTY:

if [ -z "${ORACLE_BASE}" ]
 then
  ORACLE_BASE=`grep -h 'ORACLE_BASE=\/' $USR_ORA_HOME/.bash* $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
fi

# #########################
# Getting DB_NAME:
# #########################
echo "Setting DB_NAME"
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
# Getting DB Version:
# ###################
echo "Checking DB Version"
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
echo "Checking DB Block Size"
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
echo "Checking DB Role"
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

FRACHK1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off linesize 190
col name for A40
SELECT ROUND((SPACE_USED - SPACE_RECLAIMABLE)/SPACE_LIMIT * 100, 1) FROM V\$RECOVERY_FILE_DEST;
exit;
EOF
)

FRAPRCUSED=`echo ${FRACHK1}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# Convert FRAPRCUSED from float number to integer:
FRAPRCUSED=${FRAPRCUSED%.*}
        if [ -z ${FRAPRCUSED} ]
         then
          FRAPRCUSED=1
        fi

# If FRA %USED >= the defined threshold then send an email alert:
INTEG='^[0-9]+$'
        # Verify that FRAPRCUSED value is a valid number:
        if [[ ${FRAPRCUSED} =~ ${INTEG} ]]
         then
echo "Checking FRA For [${ORACLE_SID}] ..."
               if [ ${FRAPRCUSED} -ge ${FRATHRESHOLD} ]
                 then
FRA_RPT=${LOG_DIR}/FRA_REPORT.log

FRACHK2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize 199
col name for a100
col TOTAL_MB for 99999999999999999
col FREE_MB for  99999999999999999
SPOOL ${FRA_RPT}
PROMPT
PROMPT FLASH RECOVER AREA Utilization:
PROMPT -----------------------------------------------

SELECT NAME,SPACE_LIMIT/1024/1024 TOTAL_MB,(SPACE_LIMIT - SPACE_USED + SPACE_RECLAIMABLE)/1024/1024 AS FREE_MB,
ROUND((SPACE_USED - SPACE_RECLAIMABLE)/SPACE_LIMIT * 100, 1) AS "%FULL"
FROM V\$RECOVERY_FILE_DEST;

PROMPT
PROMPT FRA COMPONENTS:
PROMPT ------------------------------

select * from v\$flash_recovery_area_usage;
spool off
exit;
EOF
)

mail -s "ALERT: FRA has reached ${FRAPRCUSED}% on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]" $MAIL_LIST < ${FRA_RPT}
               fi
        fi

rm -f ${FRAFULL}
rm -f ${FRA_RPT}
  fi


# ################################
# Check ASM Diskgroup Utilization:
# ################################
echo "Checking ASM Diskgroup Utilization ..."
VAL314=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from v\$asm_diskgroup;
exit;
EOF
)
ASM_GROUP_COUNT=`echo ${VAL314}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# If ASM DISKS Are Exist, Check the size utilization:
  if [ ${ASM_GROUP_COUNT} -gt 0 ]
   then
echo "Checking ASM on [${ORACLE_SID}] ..."

ASM_UTL=${LOG_DIR}/ASM_UTILIZATION.log

ASMCHK1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off linesize 190
col name for A40
spool ${ASM_UTL}
select name,ROUND((1-(free_mb / total_mb))*100, 2) "%FULL" from v\$asm_diskgroup;
spool off
exit;
EOF
)

ASMFULL=${LOG_DIR}/asm_full.log
#cat ${ASM_UTL}|awk '{ print $1" "$NF }'| while read OUTPUT3
cat ${ASM_UTL}|egrep -v ${EXL_DISK_GROUP}|awk '{ print $1" "$NF }'| while read OUTPUT3
   do
        ASMPRCUSED=`echo ${OUTPUT3}|awk '{print $NF}'`
        ASMDGNAME=`echo ${OUTPUT3}|awk '{print $1}'`
        echo "[Reported By ${SCRIPT_NAME} Script]"                       > ${ASMFULL}
        echo " "                                                        >> ${ASMFULL}
        echo "ASM_DISK_GROUP            %USED"                          >> ${ASMFULL}
        echo "----------------------          --------------"           >> ${ASMFULL}
        echo "${ASMDGNAME}                        ${ASMPRCUSED}%"       >> ${ASMFULL}

# Convert ASMPRCUSED from float number to integer:
ASMPRCUSED=${ASMPRCUSED%.*}
        if [ -z ${ASMPRCUSED} ]
         then
          ASMPRCUSED=1
        fi
# If ASM %USED >= the defined threshold send an email for each DISKGROUP:
               if [ ${ASMPRCUSED} -ge ${ASMTHRESHOLD} ]
                 then
ASM_RPT=${LOG_DIR}/ASM_REPORT.log

ASMCHK2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 100
set linesize 199
col name for a35
SPOOL ${ASM_RPT}
prompt
prompt ASM DISK GROUPS:
PROMPT ------------------

select name,total_mb,free_mb,ROUND((1-(free_mb / total_mb))*100, 2) "%FULL" from v\$asm_diskgroup;
spool off
exit;
EOF
)

mail -s "ALERT: ASM DISK GROUP [${ASMDGNAME}] has reached ${ASMPRCUSED}% on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]" $MAIL_LIST < ${ASM_RPT}
               fi
   done

rm -f ${ASMFULL}
rm -f ${ASM_RPT}
  fi

# #########################
# Tablespaces Size Check:
# #########################

echo "Checking TABLESPACES on [${ORACLE_SID}] ..."

        if [ ${DB_VER} -gt 10 ]
         then
# If The Database Version is 11g Onwards:

TBSCHK=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF

set pages 0 termout off echo off feedback off 
col tablespace_name for A25
col y for 999999999 heading 'Total_MB'
col z for 999999999 heading 'Used_MB'
col bused for 999.99 heading '%Used'

spool ${LOG_DIR}/tablespaces_DBA_BUNDLE.log

select tablespace_name,
       (used_space*$blksize)/(1024*1024) Used_MB,
       (tablespace_size*$blksize)/(1024*1024) Total_MB,
       used_percent "%Used"
from dba_tablespace_usage_metrics;

spool off
exit;
EOF
)

         else

# If The Database Version is 10g Backwards:
# Check if AUTOEXTEND OFF (MAXSIZE=0) is set for any of the datafiles divide by ALLOCATED size else divide by MAXSIZE:
VAL33=$(${ORACLE_HOME}/bin/sqlplus -S '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_DATA_FILES WHERE MAXBYTES=0;
exit;
EOF
)
VAL44=`echo $VAL33| awk '{print $NF}'`
                case ${VAL44} in
                "0") CALCPERCENTAGE1="((sbytes - fbytes)*100 / MAXSIZE) bused " ;;
                  *) CALCPERCENTAGE1="round(((sbytes - fbytes) / sbytes) * 100,2) bused " ;;
                esac

VAL55=$(${ORACLE_HOME}/bin/sqlplus -S '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_TEMP_FILES WHERE MAXBYTES=0;
exit;
EOF
)
VAL66=`echo $VAL55| awk '{print $NF}'`
                case ${VAL66} in
                "0") CALCPERCENTAGE2="((sbytes - fbytes)*100 / MAXSIZE) bused " ;;
                  *) CALCPERCENTAGE2="round(((sbytes - fbytes) / sbytes) * 100,2) bused " ;;
                esac

TBSCHK=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off 
col tablespace for A25
col "MAXSIZE MB" format 9999999
col x for 999999999 heading 'Allocated MB'
col y for 999999999 heading 'Free MB'
col z for 999999999 heading 'Used MB'
col bused for 999.99 heading '%Used'
--bre on report
spool ${LOG_DIR}/tablespaces_DBA_BUNDLE.log
select a.tablespace_name tablespace,bb.MAXSIZE/1024/1024 "MAXSIZE MB",sbytes/1024/1024 x,fbytes/1024/1024 y,
(sbytes - fbytes)/1024/1024 z,
$CALCPERCENTAGE1
--round(((sbytes - fbytes) / sbytes) * 100,2) bused
--((sbytes - fbytes)*100 / MAXSIZE) bused
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
select tablespace_name,null,null,null,null,null||'100.00' from dba_data_files minus select tablespace_name,null,null,null,null,null||'100.00'  from dba_free_space;
spool off
exit;
EOF
)
        fi
TBSLOG=${LOG_DIR}/tablespaces_DBA_BUNDLE.log
TBSFULL=${LOG_DIR}/full_tbs.log
#cat ${TBSLOG}|awk '{ print $1" "$NF }'| while read OUTPUT2
cat ${TBSLOG}|egrep -v ${EXL_TBS} |awk '{ print $1" "$NF }'| while read OUTPUT2
   do
        PRCUSED=`echo ${OUTPUT2}|awk '{print $NF}'`
        TBSNAME=`echo ${OUTPUT2}|awk '{print $1}'`
        echo "[Reported By ${SCRIPT_NAME} Script]"               > ${TBSFULL}
        echo " "                                                >> ${TBSFULL}
        echo "Tablespace_name          %USED"                   >> ${TBSFULL}
        echo "----------------------          --------------"   >> ${TBSFULL}
#       echo ${OUTPUT2}|awk '{print $1"                              "$NF}' >> ${TBSFULL}
        echo "${TBSNAME}                        ${PRCUSED}%"    >> ${TBSFULL}

# Convert PRCUSED from float number to integer:
PRCUSED=${PRCUSED%.*}
        if [ -z ${PRCUSED} ]
         then
          PRCUSED=1
        fi
# If the tablespace %USED >= the defined threshold send an email for each tablespace:
               if [ ${PRCUSED} -ge ${TBSTHRESHOLD} ]
                 then
mail -s "ALERT: TABLESPACE [${TBSNAME}] reached ${PRCUSED}% on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]" $MAIL_LIST < ${TBSFULL}
               fi
   done

rm -f ${LOG_DIR}/tablespaces_DBA_BUNDLE.log
rm -f ${LOG_DIR}/full_tbs.log


# ############################################
# Checking Monitored Services:
# ############################################

#case ${DB_NAME} in
#ORCL)


if [ ! -x ${SERVICEMON} ]
then
echo "Checking Monitored Services on [${ORACLE_SID}] ..."
VAL_SRVMON_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off;
prompt
select count(*) from GV\$ACTIVE_SERVICES where lower(NAME) in (${SERVICEMON}) or upper(NAME) in (${SERVICEMON});
exit;
EOF
) 
VAL_SRVMON=`echo ${VAL_SRVMON_RAW}| awk '{print $NF}'`
#echo $VAL_SRVMON_RAW
#echo $VAL_SRVMON
               if [ ${VAL_SRVMON} -lt 1 ]
                 then
VAL_SRVMON_EMAIL=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize 160 pages 0 echo off feedback off
spool ${LOG_DIR}/current_running_services.log
PROMPT
PROMPT Current Running Services: [Instance: ${ORACLE_SID}]
PROMPT ************************

select INST_ID,NAME from GV\$ACTIVE_SERVICES where NAME not in ('SYS\$BACKGROUND','SYS\$USERS');
spool off
exit;
EOF
)

mail -s "ALERT: SERVICE ${SERVICEMON} Is DOWN on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]" $MAIL_LIST < ${LOG_DIR}/current_running_services.log
rm -f ${LOG_DIR}/current_running_services.log
                fi
fi

#;;
#esac

# ############################################
# Checking BLOCKING SESSIONS ON THE DATABASE:
# ############################################

echo "Checking Blocking Sessions on [${ORACLE_SID}] ..."

VAL77=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off;
select count(*) from gv\$LOCK l1, gv\$SESSION s1, gv\$LOCK l2, gv\$SESSION s2
where s1.sid=l1.sid and s2.sid=l2.sid and l1.BLOCK=1 and l2.request > 0 and l1.id1=l2.id1 and l2.id2=l2.id2;
exit;
EOF
) 
VAL88=`echo $VAL77| awk '{print $NF}'`
               if [ ${VAL88} -ge ${BLOCKTHRESHOLD} ]
                 then
VAL99=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize 160 pages 0 echo off feedback off
col BLOCKING_STATUS for a90
spool ${LOG_DIR}/blocking_sessions.log
select 'User: '||s1.username || '@' || s1.machine || '(SID=' || s1.sid ||' ) running SQL_ID:'||s1.sql_id||'  is blocking
User: '|| s2.username || '@' || s2.machine || '(SID=' || s2.sid || ') running SQL_ID:'||s2.sql_id||' For '||s2.SECONDS_IN_WAIT||' sec
------------------------------------------------------------------------------
Warn user '||s1.username||' Or use the following statement to kill his session:
------------------------------------------------------------------------------
ALTER SYSTEM KILL SESSION '''||s1.sid||','||s1.serial#||''' immediate;' AS blocking_status
from gv\$LOCK l1, gv\$SESSION s1, gv\$LOCK l2, gv\$SESSION s2
 where s1.sid=l1.sid and s2.sid=l2.sid 
 and l1.BLOCK=1 and l2.request > 0
 and l1.id1 = l2.id1
 and l2.id2 = l2.id2
 order by s2.SECONDS_IN_WAIT desc;

prompt
prompt ----------------------------------------------------------------

Prompt Blocking Locks On Objects Level:
prompt ----------------------------------------------------------------

set linesize 160 pages 100 echo on feedback on
column OS_PID format A15 Heading "OS_PID"
column ORACLE_USER format A15 Heading "ORACLE_USER"
column LOCK_TYPE format A15 Heading "LOCK_TYPE"
column LOCK_HELD format A11 Heading "LOCK_HELD"
column LOCK_REQUESTED format A11 Heading "LOCK_REQUESTED"
column STATUS format A13 Heading "STATUS"
column OWNER format A15 Heading "OWNER"
column OBJECT_NAME format A35 Heading "OBJECT_NAME"
select  l.sid,
        ORACLE_USERNAME oracle_user,
        decode(TYPE,
                'MR', 'Media Recovery',
                'RT', 'Redo Thread',
                'UN', 'User Name',
                'TX', 'Transaction',
                'TM', 'DML',
                'UL', 'PL/SQL User Lock',
                'DX', 'Distributed Xaction',
                'CF', 'Control File',
                'IS', 'Instance State',
                'FS', 'File Set',
                'IR', 'Instance Recovery',
                'ST', 'Disk Space Transaction',
                'TS', 'Temp Segment',
                'IV', 'Library Cache Invalidation',
                'LS', 'Log Start or Switch',
                'RW', 'Row Wait',
                'SQ', 'Sequence Number',
                'TE', 'Extend Table',
                'TT', 'Temp Table', type) lock_type,
        decode(LMODE,
                0, 'None',
                1, 'Null',
                2, 'Row-S (SS)',
                3, 'Row-X (SX)',
                4, 'Share',
                5, 'S/Row-X (SSX)',
                6, 'Exclusive', lmode) lock_held,
        decode(REQUEST,
                0, 'None',
                1, 'Null',
                2, 'Row-S (SS)',
                3, 'Row-X (SX)',
                4, 'Share',
                5, 'S/Row-X (SSX)',
                6, 'Exclusive', request) lock_requested,
        decode(BLOCK,
                0, 'Not Blocking',
                1, 'Blocking',
                2, 'Global', block) status,
        OWNER,
        OBJECT_NAME
from    v\$locked_object lo,
        dba_objects do,
        v\$lock l
where   lo.OBJECT_ID = do.OBJECT_ID
AND     l.SID = lo.SESSION_ID
AND l.BLOCK='1';

prompt
prompt ----------------------------------------------------------------

Prompt Long Running Operations On DATABASE $ORACLE_SID:
prompt ----------------------------------------------------------------

col "USER | SID,SERIAL#" for a40
col MESSAGE for a80
col "%COMPLETE" for 999.99
col "SID|SERIAL#" for a12
        set linesize 200
        select USERNAME||' | '||SID||','||SERIAL# "USER | SID,SERIAL#",SQL_ID,START_TIME,SOFAR/TOTALWORK*100 "%COMPLETE",
        trunc(ELAPSED_SECONDS/60) MIN_ELAPSED, trunc(TIME_REMAINING/60) MIN_REMAINING,substr(MESSAGE,1,80)MESSAGE
        from v\$session_longops where SOFAR/TOTALWORK*100 <>'100'
        order by MIN_REMAINING;

spool off
exit;
EOF
)
mail -s "ALERT: BLOCKING SESSIONS detected on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]" $MAIL_LIST < ${LOG_DIR}/blocking_sessions.log
rm -f ${LOG_DIR}/blocking_sessions.log
                fi
  
# #########################
# Getting ALERTLOG path:
# #########################

echo "Checking ALERTLOG of [${ORACLE_SID}] ..."

VAL2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
ALERTZ=`echo $VAL2 | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log


# ###########################
# Checking Database Errors:
# ###########################

# Determine the ALERTLOG path:
        if [ -f ${ALERTDB} ]
         then
          ALERTLOG=${ALERTDB}
        elif [ -f $ORACLE_BASE/admin/${ORACLE_SID}/bdump/alert_${ORACLE_SID}.log ]
         then
          ALERTLOG=$ORACLE_BASE/admin/${ORACLE_SID}/bdump/alert_${ORACLE_SID}.log
        elif [ -f $ORACLE_HOME/diagnostics/${DB_NAME}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log ]
         then
          ALERTLOG=$ORACLE_HOME/diagnostics/${DB_NAME}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log
        else
          ALERTLOG=`/usr/bin/find ${ORACLE_BASE} -iname alert_${ORACLE_SID}.log  -print 2>/dev/null`
        fi

# Rename the old log generated by the script (if exists):
 if [ -f ${LOG_DIR}/alert_${ORACLE_SID}_new.log ]
  then
   mv ${LOG_DIR}/alert_${ORACLE_SID}_new.log ${LOG_DIR}/alert_${ORACLE_SID}_old.log
   # Create new log:
   tail -1000 ${ALERTLOG} > ${LOG_DIR}/alert_${ORACLE_SID}_new.log
   # Extract new entries by comparing old & new logs:
   echo "[Reported By ${SCRIPT_NAME} Script]"    > ${LOG_DIR}/diff_${ORACLE_SID}.log
   echo " "                                     >> ${LOG_DIR}/diff_${ORACLE_SID}.log
   diff ${LOG_DIR}/alert_${ORACLE_SID}_old.log ${LOG_DIR}/alert_${ORACLE_SID}_new.log |grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_${ORACLE_SID}.log

   # Search for errors:

   ERRORS=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'ORA-\|TNS-' |egrep -v ${EXL_ALERT_ERR}| tail -1`
   EXPFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'DM00 ' | tail -1`
   ALTERSFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'ALTER SYSTEM ' | tail -1`
   ALTERDFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'Completed: ' | tail -1`
   STARTUPFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'Starting ORACLE instance' | tail -1`
   SHUTDOWNFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'Instance shutdown complete' | tail -1`

   FILE_ATTACH=${LOG_DIR}/diff_${ORACLE_SID}.log

 else
   # Create new log:
   echo "[Reported By ${SCRIPT_NAME} Script]"    > ${LOG_DIR}/alert_${ORACLE_SID}_new.log
   echo " "                                     >> ${LOG_DIR}/alert_${ORACLE_SID}_new.log
   tail -1000 ${ALERTLOG}                       >> ${LOG_DIR}/alert_${ORACLE_SID}_new.log

   # Search for errors:
   ERRORS=`cat ${LOG_DIR}/alert_${ORACLE_SID}_new.log | grep 'ORA-\|TNS-' |egrep -v ${EXL_ALERT_ERR}| tail -1`
   FILE_ATTACH=${LOG_DIR}/alert_${ORACLE_SID}_new.log
 fi

# Send mail in case error exist:

        case "${ERRORS}" in
        *ORA-*|*TNS-*)
mail -s "ALERT: Instance [${ORACLE_SID}] on Server [${SRV_NAME}] reporting errors: ${ERRORS}" ${MAIL_LIST} < ${FILE_ATTACH} 
echo "ALERT: Instance [${ORACLE_SID}] on Server [${SRV_NAME}] reporting errors: ${ERRORS}"
	;;
        esac

                case ${PARANOIDMODE} in
                y|Y|yes|YES|Yes|true|TRUE|True|on|ON|On)

        case "${EXPFLAG}" in
        *'DM00'*)
mail -s "INFO: EXPORT/IMPORT Operation Initiated on Instance [${ORACLE_SID}] on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo "INFO: EXPORT/IMPORT Operation Initiated on Instance [${ORACLE_SID}] on Server [${SRV_NAME}]"
        ;;
        esac

        case "${ALTERSFLAG}" in
        *'ALTER SYSTEM'*)
mail -s "INFO: ALTER SYSTEM Command Executed Against Instance [${ORACLE_SID}] on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo "INFO: ALTER SYSTEM Command Executed Against Instance [${ORACLE_SID}] on Server [${SRV_NAME}]"
        ;;
        esac

        case "${ALTERDFLAG}" in
        *'Completed:'*)
mail -s "INFO: MAJOR DB ACTIVITY Completed on Instance [${ORACLE_SID}] on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo "INFO: MAJOR DB ACTIVITY Completed on Instance [${ORACLE_SID}] on Server [${SRV_NAME}]"
        ;;
        esac

        case "${STARTUPFLAG}" in
        *'Starting ORACLE instance'*)
mail -s "ALERT: Startup Event of Instance [${ORACLE_SID}] Triggered on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo "ALERT: Startup Event of Instance [${ORACLE_SID}] Triggered on Server [${SRV_NAME}]"
        ;;
        esac

        case "${SHUTDOWNFLAG}" in
        *'Instance shutdown complete'*)
mail -s "ALARM: Shutdown Event of Instance [${ORACLE_SID}] Triggered on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo "ALARM: Shutdown Event of Instance [${ORACLE_SID}] Triggered on Server [${SRV_NAME}]"
        ;;
        esac

                ;;
                esac



# #####################
# Reporting Offline DBs:
# #####################
# Populate ${LOG_DIR}/alldb_DBA_BUNDLE.log from ORATAB:
# put all running instances in one variable:
ALL_RUNNING_INSTANCES=`ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g"`
# Exclude all running instances/DB names from getting checked when reading ORATAB file:
grep -v '^\#' $ORATAB |egrep -v "${EXL_DB}"|egrep -v "${ALL_RUNNING_INSTANCES}"|grep -v "${DB_NAME_LOWER}:"| grep -v "${DB_NAME_UPPER}:"|  grep -v '^$' | grep "^" | cut -f1 -d':' > ${LOG_DIR}/alldb_DBA_BUNDLE.log

# Populate ${LOG_DIR}/updb_DBA_BUNDLE.log:
  echo ${ORACLE_SID}    >> ${LOG_DIR}/updb_DBA_BUNDLE.log
  echo ${DB_NAME}       >> ${LOG_DIR}/updb_DBA_BUNDLE.log

# End looping for databases:
done

# Continue Reporting Offline DBs...
        case ${CHKOFFLINEDB} in
        Y|y|YES|yes|Yes)
echo "Checking for Offline Databases ..."
# Sort the lines alphabetically with removing duplicates:
sort ${LOG_DIR}/updb_DBA_BUNDLE.log  | uniq -d                                  > ${LOG_DIR}/updb_DBA_BUNDLE.log.sort
sort ${LOG_DIR}/alldb_DBA_BUNDLE.log                                            > ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort
diff ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort ${LOG_DIR}/updb_DBA_BUNDLE.log.sort   > ${LOG_DIR}/diff_DBA_BUNDLE.sort
echo "The Following Instances are POSSIBLY Down/Hanged on [${SRV_NAME}]:"       > ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"       >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
grep "^< " ${LOG_DIR}/diff_DBA_BUNDLE.sort | cut -f2 -d'<'                      >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo " "                                                                        >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "If above instances are permanently offline, please add their names to 'EXL_DB' parameter at line# 90 or hash their entries in ${ORATAB} to let the script ignore them in the next run." >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
OFFLINE_DBS_NUM=`cat ${LOG_DIR}/offdb_DBA_BUNDLE.log| wc -l`
  
# If OFFLINE_DBS is not null:
        if [ ${OFFLINE_DBS_NUM} -gt 4 ]
         then
echo ""                           >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "Current Running Instances:" >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "************************"   >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
ps -ef|grep pmon|grep -v grep     >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo ""                           >> ${LOG_DIR}/offdb_DBA_BUNDLE.log

VALX1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 100;
spool ${LOG_DIR}/running_instances.log
set linesize 160
col BLOCKED for a7
col STARTUP_TIME for a19 
select instance_name INS_NAME,STATUS,DATABASE_STATUS DB_STATUS,LOGINS,BLOCKED,to_char(STARTUP_TIME,'DD-MON-YY HH24:MI:SS') STARTUP_TIME from v\$instance;
spool off
exit;
EOF
)
cat ${LOG_DIR}/running_instances.log >> ${LOG_DIR}/offdb_DBA_BUNDLE.log

mail -s "ALARM: Database Inaccessible on Server: [$SRV_NAME]" $MAIL_LIST < ${LOG_DIR}/offdb_DBA_BUNDLE.log
        fi

# Wiping Logs:
#cat /dev/null >  ${LOG_DIR}/updb_DBA_BUNDLE.log
#cat /dev/null >  ${LOG_DIR}/alldb_DBA_BUNDLE.log
#cat /dev/null >  ${LOG_DIR}/updb_DBA_BUNDLE.log.sort
#cat /dev/null >  ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort
#cat /dev/null >  ${LOG_DIR}/diff_DBA_BUNDLE.sort

rm -f ${LOG_DIR}/updb_DBA_BUNDLE.log
rm -f ${LOG_DIR}/alldb_DBA_BUNDLE.log
rm -f ${LOG_DIR}/updb_DBA_BUNDLE.log.sort
rm -f ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort
rm -f ${LOG_DIR}/diff_DBA_BUNDLE.sort

        ;;
        esac

# ###########################
# Checking Listeners log:
# ###########################
# Check if the LISTENER CHECK flag is Y:

                case ${CHKLISTENER} in
                Y|y|YES|yes|Yes)
echo "Checking Listener Log of [${ORACLE_SID}] ..."
# In case there is NO Listeners are running send an (Alarm):
LSN_COUNT=$( ps -ef|grep -v grep|grep tnslsnr|wc -l )

 if [ $LSN_COUNT -eq 0 ]
  then
   echo "The following are the LISTENERS running by user ${ORA_USER} on server ${SRV_NAME}:"     > ${LOG_DIR}/listener_processes.log
   echo "************************************************************************************"  >> ${LOG_DIR}/listener_processes.log
   ps -ef|grep -v grep|grep tnslsnr                                                             >> ${LOG_DIR}/listener_processes.log
mail -s "ALARM: No Listeners Are Running on Server: $SRV_NAME !!!" $MAIL_LIST                    < ${LOG_DIR}/listener_processes.log
  
  # In case there is listener running analyze its log:
  else
#        for LISTENER_NAME in $( ps -ef|grep -v grep|grep tnslsnr|awk '{print $(NF-1)}' )
         for LISTENER_NAME in $( ps -ef|grep -v grep|grep tnslsnr|awk '{print $(9)}' )
         do
#         LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep "${LISTENER_NAME} "|awk '{print $(NF-2)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"`
          LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep "${LISTENER_NAME} "|awk '{print $(8)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"`
          export LISTENER_HOME
          TNS_ADMIN=${LISTENER_HOME}/network/admin; export TNS_ADMIN
          export TNS_ADMIN
          LISTENER_LOGDIR=`${LISTENER_HOME}/bin/lsnrctl status ${LISTENER_NAME} |grep "Listener Log File"| awk '{print $NF}'| sed -e 's/\/alert\/log.xml//g'`
          export LISTENER_LOGDIR
          LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
          export LISTENER_LOG

          # Determine if the listener name is in Upper/Lower case:
                if [ ! -f  ${LISTENER_LOG} ]
                 then
                  # Listner_name is Uppercase:
                  LISTENER_NAME=$( echo ${LISTENER_NAME} | awk '{print toupper($0)}' )
                  export LISTENER_NAME
                  LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
                  export LISTENER_LOG
                fi
                if [ ! -f  ${LISTENER_LOG} ]
                 then
                  # Listener_name is Lowercase:
                  LISTENER_NAME=$( echo "${LISTENER_NAME}" | awk '{print tolower($0)}' )
                  export LISTENER_NAME
                  LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
                  export LISTENER_LOG
                fi

    if [ -f  ${LISTENER_LOG} ]
        then
          # Rename the old log (If exists):
          if [ -f ${LOG_DIR}/alert_${LISTENER_NAME}_new.log ]
           then
              mv ${LOG_DIR}/alert_${LISTENER_NAME}_new.log ${LOG_DIR}/alert_${LISTENER_NAME}_old.log
            # Create a new log:
              tail -1000 ${LISTENER_LOG}                 > ${LOG_DIR}/alert_${LISTENER_NAME}_new.log
            # Get the new entries:
              echo "[Reported By ${SCRIPT_NAME} Script]"  > ${LOG_DIR}/diff_${LISTENER_NAME}.log
              echo " "                                  >> ${LOG_DIR}/diff_${LISTENER_NAME}.log
              diff ${LOG_DIR}/alert_${LISTENER_NAME}_old.log  ${LOG_DIR}/alert_${LISTENER_NAME}_new.log | grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_${LISTENER_NAME}.log
            # Search for errors:
             #ERRORS=`cat ${LOG_DIR}/diff_${LISTENER_NAME}.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
             ERRORS=`cat ${LOG_DIR}/diff_${LISTENER_NAME}.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
             SRVC_REG=`cat ${LOG_DIR}/diff_${LISTENER_NAME}.log| grep "service_register" `
             FILE_ATTACH=${LOG_DIR}/diff_${LISTENER_NAME}.log

         # If no old logs exist:
         else
            # Just create a new log without doing any comparison:
             echo "[Reported By ${SCRIPT_NAME} Script]"          > ${LOG_DIR}/alert_${LISTENER_NAME}_new.log
             echo " "                                   >> ${LOG_DIR}/alert_${LISTENER_NAME}_new.log
             tail -1000 ${LISTENER_LOG}                 >> ${LOG_DIR}/alert_${LISTENER_NAME}_new.log

            # Search for errors:
              #ERRORS=`cat ${LOG_DIR}/alert_${LISTENER_NAME}_new.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
              ERRORS=`cat ${LOG_DIR}/alert_${LISTENER_NAME}_new.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
              SRVC_REG=`cat ${LOG_DIR}/alert_${LISTENER_NAME}_new.log | grep "service_register" `
              FILE_ATTACH=${LOG_DIR}/alert_${LISTENER_NAME}_new.log
         fi

          # Report TNS Errors (Alert)
            case "$ERRORS" in
            *TNS-*)
mail -s "ALERT: Listener [${LISTENER_NAME}] on Server [${SRV_NAME}] reporting errors: ${ERRORS}" $MAIL_LIST < ${FILE_ATTACH}
            esac

          # Report Registered Services to the listener (Info)
            case "$SRVC_REG" in
            *service_register*)
mail -s "INFO: Service Registered on Listener [${LISTENER_NAME}] on Server [${SRV_NAME}] | TNS poisoning possibility" $MAIL_LIST < ${FILE_ATTACH}
            esac
        else
         echo "Cannot find the listener log: <${LISTENER_LOG}> for listener ${LISTENER_NAME} !"
    fi
        done
 fi

                esac

# ###########################
# Checking Goldengate Errors:
# ###########################
# Manually Specify goldengate logfile location: [In case the script failed to find its location]
ALERTGGPATH=

# Check if the Goldengate CHECK flag is Y:

                case ${CHKGOLDENGATE} in
                Y|y|YES|yes|Yes)
echo "Checking GoldenGate log ..."

# Determine goldengate log path:
        if [ ! -z ${ALERTGGPATH} ]
         then
          GGLOG=${ALERTGGPATH}
        else
          GGLOG=`/bin/ps -ef|grep ggserr.log|grep -v grep|tail -1|awk '{print $NF}'`
        fi

# Rename the old log generated by the script (if exists):
 if [ -f ${LOG_DIR}/ggserr_new.log ]
  then
   mv ${LOG_DIR}/ggserr_new.log ${LOG_DIR}/ggserr_old.log
   # Create new log:
   tail -1000 ${GGLOG}                          > ${LOG_DIR}/ggserr_new.log

   # Extract new entries by comparing old & new logs:
   echo "[Reported By ${SCRIPT_NAME} Script]"    > ${LOG_DIR}/diff_ggserr.log
   echo " "                                     >> ${LOG_DIR}/diff_ggserr.log
   diff ${LOG_DIR}/ggserr_old.log  ${LOG_DIR}/ggserr_new.log |grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_ggserr.log

   # Search for errors:
   #ERRORS=`cat ${LOG_DIR}/diff_ggserr.log | grep 'ERROR' |egrep -v ${EXL_GG_ERR}| tail -1`
   ERRORS=`cat ${LOG_DIR}/diff_ggserr.log | grep 'ERROR' | tail -1`

   FILE_ATTACH=${LOG_DIR}/diff_ggserr.log

 else
   # Create new log:
   echo "[Reported By ${SCRIPT_NAME} Script]"    > ${LOG_DIR}/ggserr_new.log
   echo " "                                     >> ${LOG_DIR}/ggserr_new.log
   tail -1000 ${GGLOG}                          >> ${LOG_DIR}/ggserr_new.log

   # Search for errors:
   #ERRORS=`cat ${LOG_DIR}/ggserr_new.log | grep 'ERROR' |egrep -v ${EXL_GG_ERR}| tail -1`
   ERRORS=`cat ${LOG_DIR}/ggserr_new.log | grep 'ERROR' | tail -1`
   FILE_ATTACH=${LOG_DIR}/ggserr_new.log
 fi

# Send mail in case error exist:
        case ${ERRORS} in
        *ERROR*)
mail -s "Goldengate Error on Server [${SRV_NAME}]: ${ERRORS}" ${MAIL_LIST} < ${FILE_ATTACH}
        esac
                esac

# De-Neutralize login.sql file:
# If login.sql was renamed during the execution of the script revert it back to its original name:
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

