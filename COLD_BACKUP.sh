# #################################################
# Database COLD Backup Script.
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      22-12-13            #   #   # #   #  
#
# Modified:     16-05-14 Increased linesize
#			 to avoid line breaking.
#
# #################################################

# ###########
# Description:
# ###########
echo
echo "==============================================="
echo "This script Takes a COLD BACKUP for a database."
echo "==============================================="
echo
sleep 1


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"                           #Excluded INSTANCES [Will not get reported offline].

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
	  echo
	  echo "********"
          echo $DB_ID
          echo "********"
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

# Neutralize login.sql file:
# #########################
# Existance of login.sql file under current working directory eliminates many functions during the execution of this script:

        if [ -f ./login.sql ]
         then
mv ./login.sql   ./login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# ################################
# Creating Backup & Restore Script:
# ################################
echo 
echo "Enter the Backup location: [Full Path]"
echo "-------------------------"
while read LOC1
        do
                EXTEN=${ORACLE_SID}_`date '+%F'`
                LOC2=${LOC1}/COLDBACKUP_${EXTEN}
                /bin/mkdir -p ${LOC2}

                if [ ! -d "${LOC2}" ]; then
                 echo "Provided Backup Location is NOT Exist/Writable !"
                 echo
                 echo "Please Provide a VALID Backup Location:"
		 echo "---------------------------------------"
                else
                 echo
                 sleep 1
                 echo "Backup Location Validated."
                 echo
                 break
                fi
        done
BKPSCRIPT=${LOC2}/Cold_Backup.sh
RSTSCRIPT=${LOC2}/Restore_Cold_Backup.sh
BKPSCRIPTLOG=${LOC2}/Cold_Backup.log
RSTSCRIPTLOG=${LOC2}/Restore_Cold_Backup.log

# Creating the Cold Backup script:
echo
echo "Creating Cold Backup and Cold Restore Scripts ..."
sleep 1
cd ${LOC2}
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 
set termout off echo off feedback off linesize 400;
spool Cold_Backup.sh
PROMPT echo "Shutting Down Database $ORACLE_SID ... [Ctrl+c to CANCEL]"
PROMPT echo "[5]"
PROMPT sleep 1
PROMPT echo "[4]"
PROMPT sleep 1
PROMPT echo "[3]"
PROMPT sleep 1
PROMPT echo "[2]"
PROMPT sleep 1
PROMPT echo "[1]"
PROMPT sleep 1
PROMPT echo "SHUTTING DOWN NOW ..."
PROMPT sleep 3
PROMPT echo ""
PROMPT ${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT shutdown immediate;
PROMPT EOF
PROMPT echo "Database SHUTDOWN SUCCESFULLY."
PROMPT sleep 1
PROMPT echo
PROMPT echo "Starting DB FILES copy ..."
PROMPT echo
PROMPT echo "************************"
PROMPT echo "DON'T CLOSE THIS SESSION, Once the BACKUP JOB is DONE, it will return you back to the PROMPT."
PROMPT echo "************************"
PROMPT echo
PROMPT sleep 1
PROMPT
PROMPT echo -ne '...'
select 'cp -vpf '||name||' $LOC2 ; echo ' ||'-ne '''||'...''' from v\$controlfile
union
select 'cp -vpf '||name||' $LOC2 ; echo ' ||'-ne '''||'...''' from v\$datafile
union
select 'cp -vpf '||member||' $LOC2 ; echo ' ||'-ne '''||'...''' from v\$logfile;
PROMPT touch $LOC2/verifier.log
PROMPT echo

spool off
EOF
chmod 700 ${BKPSCRIPT}
# Creating the Restore Script:
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 termout off echo off feedback off linesize 400;
spool Restore_Cold_Backup.sh
PROMPT echo ""
PROMPT echo "Restoring Database $ORACLE_SID from Cold Backup [${EXTEN}] ..."
PROMPT sleep 1
PROMPT echo ""
PROMPT echo "ARE YOU SURE YOU WANT TO RESTORE DATABASE [${ORACLE_SID}] ? [Y|N] [N]"
PROMPT while read ANS
PROMPT  do
PROMPT          case \$ANS in
PROMPT                  y|Y|yes|YES|Yes) echo "RESTORATION JOB STARTED ...";break ;;;
PROMPT                  ""|n|N|no|NO|No) echo "Script Terminated.";exit;break ;;;
PROMPT                  *) echo "Please enter a VALID answer [Y|N]" ;;;
PROMPT          esac
PROMPT  done
PROMPT ORACLE_SID=${ORACLE_SID}
PROMPT export ORACLE_SID
PROMPT echo "Shutting Down Database ${ORACLE_SID} ... [Ctrl+c to CANCEL]"
PROMPT echo "[5]"
PROMPT sleep 1
PROMPT echo "[4]"
PROMPT sleep 1
PROMPT echo "[3]"
PROMPT sleep 1
PROMPT echo "[2]"
PROMPT sleep 1
PROMPT echo "[1]"
PROMPT sleep 1
PROMPT echo "SHUTTING DOWN NOW ..."
PROMPT sleep 3
PROMPT echo ""
PROMPT ${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT shutdown immediate;
PROMPT EOF
PROMPT 
PROMPT echo "Restoration Job Started ..."
PROMPT echo ""
PROMPT echo -ne '...'
select 'cp -vpf $LOC2/'||SUBSTR(name, INSTR(name,'/', -1,1)+1)||'  '||name||' ; echo ' ||'-ne '''||'...''' from v\$controlfile
union
select 'cp -vpf $LOC2/'||SUBSTR(name, INSTR(name,'/', -1,1)+1)||'  '||name||' ; echo ' ||'-ne '''||'...''' from v\$datafile
union
select 'cp -vpf $LOC2/'||SUBSTR(member, INSTR(member,'/', -1,1)+1)||'  '||member||' ; echo ' ||'-ne '''||'...''' from v\$logfile;
PROMPT echo
PROMPT ${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT startup
PROMPT PROMPT
PROMPT PROMPT Adding TEMPFILES TO TEMPORARY TABLESPACES...
select 'ALTER DATABASE TEMPFILE '''||file_name||''' DROP;' from dba_temp_files;
select 'ALTER TABLESPACE '||tablespace_name||' ADD TEMPFILE '''||file_name||''' REUSE;' from dba_temp_files;
PROMPT EOF
PROMPT VAL1=\$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT set heading off echo off feedback off termout off
PROMPT select status from v\\\$instance;;
PROMPT EOF
PROMPT )
PROMPT VAL2=\`echo \$VAL1 | perl -lpe'\$_ = reverse' |awk '{print \$1}'|perl -lpe'\$_ = reverse'\`
PROMPT case \${VAL2} in "OPEN")
PROMPT echo "******************************************************"
PROMPT echo "Database [$ORACLE_SID] has been Restored Successfully."
PROMPT echo "Database [$ORACLE_SID] is UP."
PROMPT echo "******************************************************"
PROMPT echo 
PROMPT echo ;;;
PROMPT *)
PROMPT echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
PROMPT echo "Database [$ORACLE_SID] CANNOT OPEN !"
PROMPT echo "Please check the ALERTlOG and investigate."
PROMPT echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
PROMPT echo 
PROMPT echo ;;;
PROMPT esac
spool off
EOF

chmod 700 ${RSTSCRIPT}

        if [ ! -f "${BKPSCRIPT}" ]; then
          echo ""
          echo "Backup & Restore Scripts CANNOT be Created."
          echo "Script Failed to Create the Cold Backup job !"
          echo "Please check the Backup Location permissions."
          exit
        fi

echo
echo "--------------------------------------------------------"
echo "Backup & Restore Scripts have been Created Successfully."
echo "--------------------------------------------------------"
echo
echo
sleep 1

# ############################
# Executing Cold Backup Script:
# ############################
# Checking if more than one instance is running: [RAC]
echo "Checking Other OPEN instances [RAC]."
sleep 1
VAL3=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set heading off echo off feedback off termout off
select count(*) from gv\$instance;
EOF
)
VAL4=`echo $VAL3 | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
                if [ ${VAL4} -gt 1 ]
                 then
                  echo
                  echo "WARNING:"
                  echo "-------"
                  echo "Please SHUTDOWN ALL other RAC INSTANCES EXCEPT the one on the CURRENT Node."
                  echo "Then Re-run COLD_BACKUP.sh script Again."
                  echo ""
                  exit
                fi
echo
echo "VERIFIED: Only ONE INSTANCE is RUNNING for Database [${ORACLE_SID}]."
echo
sleep 1
echo "ARE YOU SURE TO SHUTDOWN DATABASE [${ORACLE_SID}] AND START THE COLD BACKUP JOB? [Y|N] [N]"
while read ANS
 do
         case $ANS in
                 y|Y|yes|YES|Yes) echo;echo "COLD BACKUP PROCEDURE STARTED ...";break ;;
                 ""|n|N|no|NO|No) echo;echo "Script Terminated.";exit;break ;;
                 *) echo "Please enter a VALID answer [Y|N]" ;;
         esac
 done
echo
echo "Database [${ORACLE_SID}] Will SHUTDOWN within [5 Seconds] ... [To CANCEL press [Ctrl+c]]"
echo "[5]"
sleep 1
echo "[4]"
sleep 1
echo "[3]"
sleep 1
echo "[2]"
sleep 1
echo "[1]"
sleep 1
echo ""
echo "Shutting Down Database [${ORACLE_SID}] ..."
echo "Backup Files will be Copied Under: [${LOC2}] ..."
echo
sleep 1
exec ${BKPSCRIPT} |tee  ${BKPSCRIPTLOG}

 VAL11=$LOC2/verifier.log
 if [ ! -f ${VAL11} ]
  then
   echo 
   echo "xxxxxxxxxxxxxxxxxxx"
   echo "Backup Job Failed !"
   echo "xxxxxxxxxxxxxxxxxxx"
   echo
  else
   echo
   echo "Database Cold Backup is DONE."
   echo "Please Note that TEMP DATAFILES are NOT included in this Backup."
   echo
   echo "****************************************************************"
   echo "COLD BACKUP files located under: ${LOC2}"
   echo "****************************************************************"
   echo
   echo "****************************************************************"
   echo "Later, To restore database ${DB_ID} from this COLD BACKUP,"
   echo "use this script to do that job automatically:"
   echo "${RSTSCRIPT}"
   echo "****************************************************************"
 fi

rm -f ${VAL11}
echo
echo "Do You Want to STARTUP Database [${ORACLE_SID}]? [Y|N] [Y]"
echo "==========================================="
while read ANS
 do
         case $ANS in
                 ""|y|Y|yes|YES|Yes) echo "STARTING UP DATABASE [${ORACLE_SID}] ..."
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
STARTUP
EOF
echo
break ;;
                 n|N|no|NO|No) echo;echo "Script FINISHED."
echo "To restore this database from the COLD BACKUP, Run Script: [${RSTSCRIPT}]"
exit
break ;;
                 *) echo "Please enter a VALID answer [Y|N]" ;;
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
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
