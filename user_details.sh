###################################################
# This script show the user details (Creation Stmt)		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	24-09-11	    #   #   # #   # 
# Modified:	31-12-13	     
#		Customized the script to run on
#		various environments.
#		19-02-14
#		Added USER's OBJECT COUNT.
#		16-09-14 Add Search Feature.
###################################################

# ###########
# Description:
# ###########
echo
echo "========================================================"
echo "This script generates the CREATION STATEMENT for a USER."
echo "========================================================"
echo
sleep 1

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

# ################################################################
# SQLPLUS: Get the creation statement of a USER plus extra details:
# ################################################################
# Variables
echo 
echo Please enter the Username:
echo "========================="
while read USERNAME
 do
        case ${USERNAME} in
          "")echo
             echo "Enter the Username:"
             echo "==================";;
          public|PUBLIC|Public)
SPOOL_FILE="${USR_ORA_HOME}"/"${USERNAME}"_creation_stmt.log
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 lines 200
set echo off heading off feedback off
spool '$SPOOL_FILE'
select 'GRANT '||GRANTED_ROLE||' TO '||GRANTEE||';' from dba_role_privs where grantee= 'PUBLIC'
UNION
select 'GRANT '||PRIVILEGE||' TO '||GRANTEE||';' from dba_sys_privs where grantee= 'PUBLIC'
UNION
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||';'
from DBA_TAB_PRIVS where GRANTEE='PUBLIC' and OWNER not in ('SYS','SYSTEM','WMSYS','XDB','DBSNMP','OLAPSYS','ORDSYS');
spool off
EOF
        if [ -f "${SPOOL_FILE}" ]
         then
          echo;echo "The Creation Statement has been spooled in: ${SPOOL_FILE}"
          echo
        fi
          exit;break ;;
          *)
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME=upper('$USERNAME');
EOF
)
VAL22=`echo $VAL11| awk '{print $NF}'`
                        case ${VAL22} in
                        0) echo;echo "INFO: USER [${USERNAME}] IS NOT EXIST ON DATABASE [$ORACLE_SID] !"
                           echo; echo "Searching..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pagesize 1000 lines 200
set feedback off
set trim on
set echo off
col USERNAME for a30
col account_status for a23
select username,account_status,profile from dba_users where username like upper ('%$USERNAME%');
EOF
                           echo; echo "Please Enter the FULL USERID:";echo "=============================" ;;
                        *) break;;
                        esac
          esac
 done

SPOOL_FILE="${USR_ORA_HOME}"/"${USERNAME}"_creation_stmt.log
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 lines 200
set echo off heading off feedback off
spool '$SPOOL_FILE'
SELECT 'CREATE USER ' || u.username ||' IDENTIFIED ' ||' BY VALUES ''' || c.password || ''' DEFAULT TABLESPACE ' || u.default_tablespace ||' TEMPORARY TABLESPACE ' || u.temporary_tablespace ||' PROFILE ' || u.profile || case when account_status= 'OPEN' then ';' else ' Account LOCK;' end "--Creation Statement"
FROM dba_users u,user$ c where u.username=c.name and u.username=upper('$USERNAME')
UNION
select 'GRANT '||GRANTED_ROLE||' TO '||GRANTEE|| case when ADMIN_OPTION='YES' then ' WITH ADMIN OPTION;' else ';' end "Granted Roles"
from dba_role_privs where grantee= upper('$USERNAME')
UNION
select 'GRANT '||PRIVILEGE||' TO '||GRANTEE|| case when ADMIN_OPTION='YES' then ' WITH ADMIN OPTION;' else ';' end "Granted System Privileges"
from dba_sys_privs where grantee= upper('$USERNAME')
UNION
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||case when GRANTABLE='YES' then ' WITH GRANT OPTION;' else ';' end "Granted Object Privileges"
from DBA_TAB_PRIVS where GRANTEE=upper('$USERNAME');
spool off
set heading on pages 1000
col USERNAME for a25
col PASSWORD for a25
col account_status for a23
col PROFILE for a15
col DEFAULT_TABLESPACE for a20
col TEMPORARY_TABLESPACE for a20
PROMPT
SELECT A.USERNAME,B.PASSWORD,A.ACCOUNT_STATUS,A.PROFILE,A.DEFAULT_TABLESPACE,A.TEMPORARY_TABLESPACE FROM DBA_USERS A, USER$ B WHERE A.USER_ID=B.USER# AND USERNAME=UPPER('$USERNAME');
PROMPT
PROMPT USER's OBJECT COUNT:
PROMPT --------------------

select  USERNAME,
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
from    obj$ o,
        dba_users u
where   u.USER_ID = o.OWNER# (+) and u.USERNAME=upper('$USERNAME')
group   by USERNAME
order   by USERNAME;
set heading off
PROMPT
select 'SCHEMA SIZE: '||ceil(sum(bytes)/1024/1024)||' MB' from dba_segments where owner=UPPER('$USERNAME') group by owner;
PROMPT ------------

PROMPT
select 	'Number of Invalid Objects: '||count(*) from dba_objects where STATUS = 'INVALID' and owner=upper('$USERNAME');
PROMPT   --------------------------

PROMPT
select 'Number of Connected Sessions: ' || count(*) from gv\$session where username=upper('$USERNAME');
PROMPT  -----------------------------

EOF
	if [ -f "${SPOOL_FILE}" ]
	 then
	  echo;echo "The Creation Statement has been spooled in: ${SPOOL_FILE}"
	  echo
	fi

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
