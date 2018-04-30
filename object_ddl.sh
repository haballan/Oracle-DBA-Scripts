# #################################################
# This script shows object's DDL statement.
# To be run by ORACLE user		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	01-02-2013	    #   #   # #   # 
#		16-09-2014 Add Search Feature
#			   
#
# #################################################

# ###########
# Description:
# ###########
echo
echo "============================================="
echo "This script retreives object's DDL statement."
echo "============================================="
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
# SQLPLUS Section:
# #########################
# PROMPT FOR VARIABLES:
# ####################
echo ""
echo "Please Enter the OBJECT OWNER:"
echo "============================="
while read OBJECT_OWNER
 do
        if [ -z ${OBJECT_OWNER} ]
         then
          echo
          echo "Enter the OBJECT OWNER:"
          echo "======================"
         else
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME=upper('$OBJECT_OWNER');
EOF
)
VAL22=`echo $VAL11| awk '{print $NF}'`
                if [ ${VAL22} -eq 0 ]
                 then
                  echo
                  echo "INFO: SCHEMA [${OBJECT_OWNER}] IS NOT EXIST ON DATABASE [$ORACLE_SID] !"
                  echo; echo "Searching for existing SCHEMAS matching the provided string ..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
select username "Users match provided string" from dba_users where username like upper ('%$OBJECT_OWNER%');
EOF
                  echo; echo "Enter a VALID SCHEMA USER:"
                        echo "========================="
                 else
                  break
                fi
        fi
 done

echo
echo "Please Enter the OBJECT NAME:"
echo "============================"
while read OBJECT_NAME
 do
        if [ -z ${OBJECT_NAME} ]
         then
          echo
          echo "Enter the OBJECT NAME:"
          echo "====================="
         else
VAL3=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_OBJECTS WHERE OWNER=upper('$OBJECT_OWNER') AND OBJECT_NAME=UPPER('$OBJECT_NAME');
EOF
)
VAL4=`echo $VAL3| awk '{print $NF}'`
                if [ ${VAL4} -eq 0 ]
                 then
                  echo
                  echo "INFO: OBJECT [${OBJECT_NAME}] IS NOT EXIST UNDER SCHEMA [$OBJECT_OWNER] !"
                  echo; echo "Searching the database for objects having similar name ..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
col OBJECT_NAME for a45
col OBJECT_TYPE for a45
select OWNER,OBJECT_NAME,OBJECT_TYPE FROM DBA_OBJECTS WHERE OBJECT_NAME like UPPER('%$OBJECT_NAME%') order by OWNER;
EOF
                  echo; echo "Enter a VALID OBJECT NAME:"
                        echo "========================="
                 else
                  break
                fi
        fi
 done

# Getting Object Type:
# ###################
VAL7=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set heading off echo off feedback off
SELECT object_type from dba_objects where owner=upper('$OBJECT_OWNER') and object_name=upper('$OBJECT_NAME');
EOF
)
OBJECT_TYPE1=`echo $VAL7| awk '{print $(NF)}'`

		case $OBJECT_TYPE1 in
                  # Correct the value of BODY to PACKAGE BODY:
                  "BODY") OBJECT_TYPE="PACKAGE"
# Execution of SQL Statement:
# ##########################
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 linesize 200 heading off
PROMPT
PROMPT RETRIEVING DDL STATEMENT FOR $OBJECT_TYPE:  [$OBJECT_OWNER.$OBJECT_NAME] ...
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
set long 10000000
col DDL_STATEMENT for a200
SELECT dbms_metadata.get_ddl(upper('$OBJECT_TYPE'),upper('$OBJECT_NAME'),upper('$OBJECT_OWNER')) DDL_STATEMENT FROM dual;
PROMPT /
PROMPT
PROMPT Granted Privileges:
PROMPT >>>>>>>>>>>>>>>>>>
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||';' from DBA_TAB_PRIVS where owner=upper('$OBJECT_OWNER') and table_name=upper('$OBJECT_NAME');
EOF
;;

                  "LINK") OBJECT_TYPE="DB_LINK"
# Execution of SQL Statement:
# ##########################
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 linesize 200 heading off
PROMPT
PROMPT RETRIEVING DDL STATEMENT FOR $OBJECT_TYPE:  [$OBJECT_OWNER.$OBJECT_NAME] ...
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
set long 10000000 
col DDL_STATEMENT for a200
SELECT dbms_metadata.get_ddl(upper('$OBJECT_TYPE'),upper('$OBJECT_NAME'),upper('$OBJECT_OWNER')) DDL_STATEMENT FROM dual;
PROMPT /
PROMPT
PROMPT Granted Privileges:
PROMPT >>>>>>>>>>>>>>>>>>
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||';' from DBA_TAB_PRIVS where owner=upper('$OBJECT_OWNER') and table_name=upper('$OBJECT_NAME');
EOF
;;
                  "PROGRAM"|"JOB"|"SCHEDULE") OBJECT_TYPE="PROCOBJ"
# Execution of SQL Statement:
# ##########################
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 linesize 200 heading off
PROMPT
PROMPT RETRIEVING DDL STATEMENT FOR $OBJECT_TYPE1:  [$OBJECT_OWNER.$OBJECT_NAME] ...
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
set long 10000000
col DDL_STATEMENT for a200
SELECT dbms_metadata.get_ddl(upper('$OBJECT_TYPE'),upper('$OBJECT_NAME'),upper('$OBJECT_OWNER')) DDL_STATEMENT FROM dual;
PROMPT /
PROMPT
PROMPT Granted Privileges:
PROMPT >>>>>>>>>>>>>>>>>>
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||';' from DBA_TAB_PRIVS where owner=upper('$OBJECT_OWNER') and table_name=upper('$OBJECT_NAME');
EOF
;;
		  *) OBJECT_TYPE=${OBJECT_TYPE1}
# Execution of SQL Statement:
# ##########################
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 linesize 200 heading off
PROMPT
PROMPT RETRIEVING DDL STATEMENT FOR $OBJECT_TYPE:  [$OBJECT_OWNER.$OBJECT_NAME] ...
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
set long 10000000
col DDL_STATEMENT for a200
SELECT dbms_metadata.get_ddl(upper('$OBJECT_TYPE'),upper('$OBJECT_NAME'),upper('$OBJECT_OWNER')) DDL_STATEMENT FROM dual;
PROMPT /
PROMPT
PROMPT Granted Privileges:
PROMPT >>>>>>>>>>>>>>>>>>
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||';' from DBA_TAB_PRIVS where owner=upper('$OBJECT_OWNER') and table_name=upper('$OBJECT_NAME');
EOF
;;
		esac

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
