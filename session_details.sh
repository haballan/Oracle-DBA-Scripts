# #################################################
# Script to get session information	
# Ver [3.4]
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	03-02-11	    #   #   # #   # 
# Modified:	31-12-13	     
#		Customized the script to run on
#		various environments.
#               26-04-14	Added Wait Info
#		29-10-14	AUTO understand
#				user inputs.
#
#
# #################################################
SCRIPT_NAME="session_details"
# ###########
# Description:
# ###########
echo
echo "================================================================"
echo "This script Gets SESSION Information on the current instance ..."
echo "================================================================"
echo
sleep 1

# ##########
# VARIABLES:
# ##########

# Define the MAXSIZE for the LOGFILE in KB:
# 100 MB:
MAXSIZE=102400

# Define the LOGFILE PATH:
export LOG_DIR=~/BUNDLE_Logs

        if [ ! -d ${LOG_DIR} ]
         then
          export LOG_DIR=/tmp
        fi

LOGFILE=${LOG_DIR}/SESSIONS.log

if [ -f ${LOGFILE} ]
 then
LOGSIZE=$(du -k ${LOGFILE} | cut -f 1)

	if [ ${LOGSIZE} -ge ${MAXSIZE} ]
 	 then
  	 # Flush the logfile:
  	 cat /dev/null > ${LOGFILE}
	fi
fi

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
# #########################
# Existance of login.sql file under current working directory eliminates many functions during the execution of this script:

        if [ -f ./login.sql ]
         then
mv ./login.sql   ./login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# ###############################
# SQLPLUS: Getting Session Info:
# ###############################
echo
echo "Enter the USERNAME or SESSION SID: [Blank value means list all sessions on the current instance]"
echo "=================================="
while read ANS
 do
                 case $ANS in
		 # case the input is non-numeric value:
		 *[!0-9]*) echo
			if [ -z "${ANS}" ]
	 		then

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set feedback off linesize 210 pages 1000
col "USERNAME|UNIX_PID|SID,SERIAL#" for a45
col "MACHINE | MODULE" for a40
col event for a28
col "STATUS|WAITD|ACT_SINC|LOG_T" for a45
col "I|BLKD_BY" for a9

select s.USERNAME||' | ' ||p.spid ||' | '||s.sid||','||s.serial# "USERNAME|UNIX_PID|SID,SERIAL#",s.MACHINE||' | '||s.MODULE "MACHINE | MODULE"
--,w.event,substr(s.status||'|'||w.seconds_in_wait||'sec',1,30) "STATUS|TIME_WAITED"
,substr(s.status||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||LOGON_TIME,1,45) "ST|WAITD|ACT_SINC|LOG_T"
,substr(w.event,1,28)"EVENT"
--,s.CLIENT_IDENTIFIER
,s.PREV_SQL_ID "PREV_SQL_ID",s.sql_id "CURR_SQL_ID"
,s.FINAL_BLOCKING_INSTANCE||'|'||s.FINAL_BLOCKING_SESSION "I|BLKD_BY"
from v\$session s,v\$process p, v\$session_wait w,v\$sql q
where s.USERNAME like upper ('%$ANS%')
and p.addr = s.paddr
and s.sid=w.sid
order by s.USERNAME||' | '||s.sid||','||s.serial#||' | '||p.spid,MODULE;
EOF
			else

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
col "Previous SQL" for a210
col "Current SQL" for a210
set feedback off linesize 210 pages 1000
col "USER|UNXPID|SID,SER|MACH|MOD" for a54
col event for a23
col "STATUS|WAITD|ACT_SINC|LOG_T" for a45
col "I|BLKD_BY" for a9

select s.USERNAME||'|'||p.spid ||'|'||s.sid||','||s.serial#||'|'||s.MACHINE||'|'||s.MODULE "USER|UNXPID|SID,SER|MACH|MOD"
,substr(s.status||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||s.LAST_CALL_ET||'|'||s.LOGON_TIME,1,45) "ST|WAITD|ACT_SINC|LOG_T"
,substr(w.event,1,23)"EVENT"
,s.PREV_SQL_ID "PREV_SQL_ID"
,s.sql_id "CURR_SQL_ID"
,s.FINAL_BLOCKING_INSTANCE||'|'||s.FINAL_BLOCKING_SESSION "I|BLKD_BY"
--,s.CLIENT_IDENTIFIER
from v\$session s,v\$process p, v\$session_wait w
where s.USERNAME like upper ('%$ANS%')
and p.addr = s.paddr
and s.sid=w.sid;
--order by "INS|USER|SID,SER|MACHIN|MODUL";
Prompt Previous SQL Statement:
prompt -----------------------

select s.PREV_SQL_ID,q.SQL_FULLTEXT "Previous SQL"
from v\$session s,v\$process p,v\$sql q, v\$session_wait w
where s.USERNAME like upper ('%$ANS%')
and p.addr = s.paddr
and s.sid=w.sid
and q.child_number=0
and q.sql_id=s.PREV_SQL_ID;

prompt
Prompt Current Running SQL Statement:
prompt ------------------------------

select s.SQL_ID CURR_SQL_ID,q.SQL_FULLTEXT "Current SQL"
from v\$process p,v\$session s ,v\$sql q, v\$session_wait w
where s.USERNAME like upper ('%$ANS%')
and p.addr = s.paddr 
and s.sid=w.sid
and q.child_number=0
and q.sql_id=s.sql_id;
EOF
			fi
                        echo;
# De-Neutralize login.sql file:
# ############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ./login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ./login.sql_NeutralizedBy${SCRIPT_NAME}  ./login.sql
        fi
			exit ;;
			*) echo
                        if [ -z "${ANS}" ]
                        then
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set feedback off
set pages 0
spool ${LOGFILE} APPEND
prompt
select 'Timestamp: '||to_char(sysdate, 'DD-Mon-YYYY HH24:MI:SS') from dual;
prompt ===================================
prompt ALL sessions in the Database...
prompt ===================================
prompt

set feedback off linesize 220 pages 1000
col inst for 99
col module for a27
col event for a28
col MACHINE for a27
col "STATUS|WAITD|ACT_SINC|LOG_T" for a45
col "INST|USER|SID,SERIAL#" for a30
col "INS|USER|SID,SER|MACHIN|MODUL" for a72
select
substr(S.USERNAME||' | '||p.spid||'|'||s.sid||','||s.serial#||' | '||substr(s.MACHINE,1,27)||' | '||substr(s.MODULE,1,27),1,72)"USER|SPID|SID,SER|MACHIN|MODUL"
--select s.INST_ID||'|'||s.USERNAME||' | '||s.sid||','||s.serial# "INST|USER|SID,SERIAL#"
--,substr(s.MODULE,1,27)"MODULE"
--,substr(s.MACHINE,1,27)"MACHINE"
--,substr(s.status||'|'||w.state||'|'||w.WAIT_TIME_MICRO||'|'||LAST_CALL_ET||'|'||LOGON_TIME,1,50) "ST|WA_ST|WAITD|ACT_SINC|LOG_T"
,substr(s.status||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||LOGON_TIME,1,45) "STATUS|WAITD|ACT_SINC|LOG_T"
,substr(w.event,1,28)"EVENT"
--,s.PREV_SQL_ID
,s.SQL_ID CURR_SQL_ID
from v\$session s, v\$session_wait w ,v\$process p
where   s.USERNAME is not null
and 	p.addr = s.paddr
and     s.sid=w.sid
order by "USER|SPID|SID,SER|MACHIN|MODUL","STATUS|WAITD|ACT_SINC|LOG_T" desc;

set pages 1000
col MACHINE for a70
col MODULE for a70
PROMPT
PROMPT SESSIONS Distribution:
PROMPT ----------------------

PROMPT PER MODULE:
select INST_ID,MODULE,count(*)  "TOTAL_SESSIONS" from gv\$session group by INST_ID,module  order by INST_ID,count(*) desc,MODULE;
PROMPT
PROMPT PER MACHINE:
select INST_ID,MACHINE,count(*) "TOTAL_SESSIONS" from gv\$session group by INST_ID,MACHINE order by INST_ID,count(*) desc,MACHINE;

PROMPT
set pages 0
select 'ACTIVE SESSIONS:      '||count(*)  from gv\$session where USERNAME is not null and status='ACTIVE';
select 'INACTIVE SESSIONS:    '||count(*)  from gv\$session where USERNAME is not null and status='INACTIVE';
select 'BACKGROUND SESSIONS:  '||count(*)  from gv\$session where USERNAME is null; 
PROMPT --------------------  ------

select 'TOTAL SESSIONS:       '||count(*)  from gv\$session;
PROMPT
EOF

                        else

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set feedback off linesize 210 pages 1000
col "DBUSER|OSUSER|UNXPID|SID,SER" for a50
col "MACHINE | MODULE" for a40
col event for a28
col "STATUS|WAITD|ACT_SINC|LOG_T" for a45
col "I|BLKD_BY" for a12

select s.USERNAME||'|'||s.OSUSER||' |'||p.spid ||' |'||s.sid||','||s.serial# "DBUSER|OSUSER|UNXPID|SID,SER",s.MACHINE||' | '||s.MODULE "MACHINE | MODULE"
--,w.event,substr(s.status||'|'||w.state||'|'||w.seconds_in_wait||'sec',1,30) "STATUS|WAIT_STATE|TIME_WAITED"
,substr(s.status||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||LOGON_TIME,1,45) "STATUS|WAITD|ACT_SINC|LOG_T"
,substr(w.event,1,28)"EVENT"
,s.FINAL_BLOCKING_INSTANCE||'|'||s.FINAL_BLOCKING_SESSION "I|BLKD_BY"
,s.CLIENT_IDENTIFIER
,s.PREV_SQL_ID "PREV_SQL_ID",s.sql_id "CURR_SQL_ID"
from v\$session s,v\$process p, v\$session_wait w
where s.SID ='$ANS'
and p.addr = s.paddr
and s.sid=w.sid;

prompt
col "Previous SQL" for a140
select q.SQL_ID,q.SQL_FULLTEXT "Previous SQL"
from v\$process p,v\$session s ,v\$sql q
where s.SID ='$ANS'
and p.addr = s.paddr
and q.sql_id=s.PREV_SQL_ID;

prompt
col "Current SQL" for a140
select q.SQL_ID,q.SQL_FULLTEXT "Current SQL"
from v\$process p,v\$session s ,v\$sql q
where s.SID ='$ANS'
and p.addr = s.paddr
and q.sql_id=s.sql_id;
EOF
			fi
		echo;
# De-Neutralize login.sql file:
# ############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ./login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ./login.sql_NeutralizedBy${SCRIPT_NAME}  ./login.sql
        fi
		exit ;;

		esac
 done

# De-Neutralize login.sql file:
# ############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ./login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ./login.sql_NeutralizedBy${SCRIPT_NAME}  ./login.sql
        fi

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
