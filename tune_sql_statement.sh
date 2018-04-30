# #################################################################################
# This Script use SQL TUNING ADVISOR to tune a SQL Statement by providing its SQLID
# Note: [Diagnostic & Tuning License should be acquired on the underlying DB]		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	15-06-16	    #   #   # #   # 
# Modified:	00-00-00	     			
#
# #################################################################################

# ###########
# Description:
# ###########
echo
echo "=================================================================================="
echo "This script use SQL TUNING ADVISOR to tune a SQL Statement by providing its SQLID."
echo "=================================================================================="
echo
sleep 1

# ###########################
# Listing Available Databases:
# ###########################
ORACLE_OWNER_VFY="N"
SKIPDBS="ASM\|MGMTDB"

# Count Instance Numbers:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )

# Exit if No DBs are running:
if [ $INS_COUNT -eq 0 ]
 then
   echo No Databases Are Running On This Machine!
   exit
fi

# If there is ONLY one DB set it as a default without prompt for selection:
if [ $INS_COUNT -eq 1 ]
 then
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|grep -v ${SKIPDBS}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# If there is more than one DB ASK the user to select from the list:
elif [ $INS_COUNT -gt 1 ]
 then
    echo
    echo "Select the ORACLE_SID:[Enter the number]"
    echo ---------------------
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|grep -v ${SKIPDBS}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
	if [ -z "${REPLY##[0-9]*}" ]
	 then
          export ORACLE_SID=$DB_ID
          echo Selected Instance:
          echo
          echo "********"
          echo $DB_ID
          echo "********"
          echo
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
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|grep -v ASM|grep -v "\-MGMTDB"|awk '{print $1}'|tail -1`
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
case ${ORACLE_OWNER_VFY} in
                "Y")
CURR_USER=`whoami`
	if [ ${ORA_USER} != ${CURR_USER} ]; then
	  echo ""
	  echo "You're Running This Sctipt with User: \"${CURR_USER}\" !!!"
	  echo "Please Run This Script With The Right OS User: \"${ORA_USER}\""
	  echo "Script Terminated!"
	  exit
	fi;;
		esac

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

        if [ ${DB_VER} -lt 10 ]
         then     
		echo "Database Version is very old."
		echo "This Script is not compatible with this database version [${DB_VER}]."
		echo "Script Terminated!"
	fi

# #################################
# SQLPLUS:
# #################################
# Variables:
# #########
echo "" 
echo "Please provide the SQLID for the SQL Statement you want to tune:"
echo "==============================================================="
while read SQLID
do

VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM V\$SQL WHERE SQL_ID='$SQLID';
EOF
)
VAL2=`echo ${VAL1}| awk '{print $NF}'`

                        if [ ${VAL2} -gt 0 ]
			 then

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
--PROMPT
--PROMPT SQL Statement Full Text:
--PROMPT -----------------------

--SET LONG 999999999 PAGESIZE 10000 LINESIZE 200
--col SQL_FULLTEXT for a200
--select SQL_FULLTEXT from V\$SQL where SQL_ID='$SQLID';

PROMPT
PROMPT Creating SQL Tuning Task: "${SQLID}_Tuning_Task" ...
DECLARE
   l_sql_tune_task_id  VARCHAR2(100);
   BEGIN
   l_sql_tune_task_id := DBMS_SQLTUNE.create_tuning_task (
             sql_id      => '${SQLID}',
             scope       => DBMS_SQLTUNE.scope_comprehensive,
             time_limit  => 3600,
             task_name   => '${SQLID}_Tuning_Task',
             description => 'Tuning task for statement ${SQLID}');
   DBMS_OUTPUT.put_line('l_sql_tune_task_id: ' || l_sql_tune_task_id);
   END;
   /

PROMPT Executing TUNING Task: "${SQLID}_Tuning_Task" ...
PROMPT
PROMPT Please Wait! This May Take Several Minutes ...
EXEC DBMS_SQLTUNE.execute_tuning_task(task_name => '${SQLID}_Tuning_Task');

PROMPT 
PROMPT SQL Tuning Recommendations:
PROMPT --------------------------

SET LONG 999999999 PAGESIZE 10000 LINESIZE 200
SELECT DBMS_SQLTUNE.report_tuning_task('${SQLID}_Tuning_Task') AS recommendations FROM dual;

PROMPT
PROMPT Dropping Tuning Task "${SQLID}_Tuning_Task" ... 
exec dbms_sqltune.drop_tuning_task(task_name => '${SQLID}_Tuning_Task');
PROMPT 
EOF

break
			else
			echo
			echo "<<< The Provided SQLID is not found in v\$SQL view ! >>>"
			echo 
			echo "Please Enter a Valid SQLID:"
			echo "---------------------------"
			fi
done
			

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
