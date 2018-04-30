###################################################
# Shutting Down All Databases & Listeners
# VER 1.2
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	13-01-2014	    #   #   # #   #  
#
###################################################
SCRIPT_NAME="SHUTDOWN_All.sh"
SRV_NAME=`uname -n`

#############
# Description:
#############
echo
echo "===================================================================="
echo "This script SHUTDOWN All Running Databases & Listeners on the SERVER..."
echo "===================================================================="
echo
sleep 2



# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"                           #Excluded INSTANCES [Will not get reported offline].

###########################
# Getting ORACLE_SID
###########################
# Exit with sending Alert mail if No DBs are running:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )
	if [ $INS_COUNT -eq 0 ]
	 then
	  echo "No Databases Are Currently Running !"
 	  exit
	fi

# Setting ORACLE_SID:
####################

for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

# #########################
# Getting ORACLE_HOME
# #########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|egrep -v ${EXL_DB}|grep -v "\-MGMTDB"|awk '{print $1}'|tail -1`
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

###########################
# Getting DB_NAME:
###########################
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
        else
                DB_NAME=$DB_NAME_LOWER
     fi

###########################
# Variables:
###########################
export PATH=$PATH:${ORACLE_HOME}/bin
export LOG_DIR=$USR_ORA_HOME/Logs

##########################
# Getting ORACLE_BASE:
##########################

# Get ORACLE_BASE from user's profile if it EMPTY:

if [ -z "${ORACLE_BASE}" ]
 then
  ORACLE_BASE=`grep -h 'ORACLE_BASE=\/' $USR_ORA_HOME/.bash* $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
fi

#############################
# Stop All Listeners:
#############################

# Setting a Verifier:
echo "Are You SURE to Shutdown All Running Databases and Listeners? [Y|N] [N]"
echo "============================================================"
while read ANS
 do
                 case $ANS in
                 y|Y|yes|YES|Yes) echo;break ;;
		 ""|n|N|NO|no|No) echo; echo "SCRIPT TERMINATED."; exit;break ;;
		 *) echo "Please Provide a VALID Answer: [Y|N] [N]"
		    echo "=============================" ;;
		 esac
 done

echo "Shutting Down All Listeners & Databases After [10 seconds] ..."
echo "You can TERMINATE this Procedure by pressing [Ctrl+c]"
echo ""
sleep 10
echo "."
sleep 1
echo ".."
sleep 1
echo "..."
sleep 1
echo
echo "Shutting Down ALL Databases and Listeners ..."
echo ""
sleep 1
# In case there is NO Listeners are running send an Info Message:
LSN_COUNT=$( ps -ef|grep -v grep|grep tnslsnr|wc -l )

 if [ $LSN_COUNT -eq 0 ]
  then
   echo "FYI: No Listeners Are Running on This Server."
  else
   for LISTENER_NAME in $( ps -ef|grep -v grep|grep tnslsnr|awk '{print $(NF-1)}' )
   do
    LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep ${LISTENER_NAME}|awk '{print $(NF-2)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"`
    TNS_ADMIN=${LISTENER_HOME}/network/admin; export TNS_ADMIN
    ${ORACLE_HOME}/bin/lsnrctl stop ${LISTENER_NAME}
   done 
 fi

#############################
# Shuting Down DB:
#############################

INS_UP=$( ps -ef|grep pmon|grep -v grep|wc -l )
	if [ $INS_UP -gt 0 ]
	 then
	  echo "Shutting Down All Running Instances:"
	  for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   	  do
VAL2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
ALERTZ=`echo $VAL2 | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log
	echo "Shutting Down Instance ${ORACLE_SID} ..."
	echo "If Hanging Check The Alertlog:"
	echo "tail -50f ${ALERTDB}"
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
prompt
alter system checkpoint;
alter system checkpoint;
alter system checkpoint;
shutdown immediate;
exit;
EOF
	  echo "Instance ${ORACLE_SID} Shut Down Successfully"
	  echo ">> >> >>"
   	  done
	  exit
	 else
	  echo "ALL INSTANCES ARE DOWN."
	fi

done

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
