# ##################################################
# Script to generate ORABEDUG report.
# To be run on hanged instance.
# Author:       Mahmmoud ADEL        	#   #     #
#			 	      # # # #   ###
#				    #   #   # #   # 
# Created:      24-01-17
#
#
#
#
#
# ##################################################

# ############
# Description:
# ############
echo
echo "================================================================"
echo "This script runs ORADEBUG to dump HANG analysis into trace file."
echo "================================================================"
echo
sleep 1
echo -e "\033[33;5mORADEBUG utility should be run in SEVERE cases; where the instance is totally hanged as it may crash your instance!\033[0m"
sleep 3

# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"                           #Excluded INSTANCES [Will not get reported offline].

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


# ################################
# SQLPLUS: RUN ORADEBUG:
# ################################
echo
echo "Enter the HANG ANALYSIS level: [Enter one of these values [1,2,3,4,5,10]]"
echo "------------------------------"
echo "<The higher the level the more details will be captured in the log>"
while read ANALYZE_LEVEL
 do
                 case ${ANALYZE_LEVEL} in
                 "1"|"2"|"3"|"4"|"5"|"10") echo;echo "Hang Analysis Level is: ${ANALYZE_LEVEL}";
                 break ;;
                 *) echo
		    echo "Invalid Hang Analysis Level, please enter a value between [1,2,3,4,5,10]:"
		    echo "------------------------------------------------------------------------";;
			  
                 esac
 done

echo
echo "Select the option you want to run ORABEDUG with? [DB(1) <DEFAULT> or SYSTEMSTATE(2)]"
echo "================================================"
echo "[1] to run ORADEBUG against the DATABASE. [DEFAULT]"
echo "[2] to run ORADEBUG with SYSTEMSTATE option."
echo "Enter [1 or 2]:"
while read ANS
 do
                 case $ANS in
                 ""|"1"|"DB"|"db") echo;echo "ORADEBUG will analyze DB hang now ...";sleep 1

${ORACLE_HOME}/bin/sqlplus -s '/nolog' << EOF
set _prelim on
conn / as sysdba
oradebug setmypid
-- perform cluster DB wide HANGANALYZE:
oradebug setinst all
-- Set tracefile size unlimited:
oradebug unlimit
--oradebug tracefile_name
--oradebug -g def hanganalyze ${ANALYZE_LEVEL}
oradebug -g all hanganalyze ${ANALYZE_LEVEL}
--oradebug tracefile_name
--Flush any pending writes to the trace file and close it:
oradebug flush
oradebug close_trace

EOF
                 break;;
                 "2"|"SYSTEMSTATE"|"systemstate"|"SYSTEM"|"system") echo; echo "ORADEBUG will analyze SYSTEMSTATE hang now ...";echo;sleep 1;

${ORACLE_HOME}/bin/sqlplus -s '/nolog' << EOF
set _prelim on
conn / as sysdba
oradebug setmypid
-- Set tracefile size unlimited:
oradebug unlimit
-- Run ORADEBUG:
--oradebug dump crs ${ANALYZE_LEVEL}
oradebug -g all dump systemstate 266
oradebug tracefile_name
--Flush any pending writes to the trace file and close it:
oradebug flush
oradebug close_trace

EOF
break ;;
                 *) echo "Please enter a VALID answer [1|2|DB|CLUSTERWARE]";
		    echo "================================================" ;;
                esac

 done

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
