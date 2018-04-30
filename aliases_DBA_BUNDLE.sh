# ###########################################################################################
# DBA BUNDLE [4.3]
# Extract the DBA_BUNDLE & Set Command Aliases
# 					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	02-01-14	    #   #   # #   #  
# Modified:	13-01-14
#		Force using "." command 
#		01-10-16 Added more aliases
#		27-12-17 Added more aliases for new scripts for V[4.0]
#		14-02-18 SQLPLUS to use login.sql.sav under bundle directory
#		20-03-18 Added raclog/asmalert aliases for clusterware and ASM instance.
#
#
#
###########################################################################################
export SCRIPT_NAME="aliases_DBA_BUNDLE"
export BUNDLE_NAME="DBA_BUNDLE4"
export SRV_NAME=`uname -n`

USEDCOMM=`history|tail -1|awk '{print $2}'|egrep '(bundle|source|\.)'|grep -v '\.\/'`
        if [ -z "${USEDCOMM}" ]
         then
          echo ""
          echo "Please Use \".\" command to run this script."
          echo "e.g."
          echo ". ~/${BUNDLE_NAME}/aliases_DBA_BUNDLE.sh"
          echo ""
	  #exit 1
	  return
        fi

# ###########################
# Extract The Bundle: [The user should do it manually to avoid mistakes]
# ###########################

# Check the existence of the TAR file:
#	if [ -f ./${BUNDLE_NAME}.tar ]
#	 then
#	  echo "Extracting The DBA_BUNDLE..."
#	  tar xvf ./DBA_BUNDLE.tar
#	 else
#	  echo "The TAR file DBA_BUNDLE.tar is not exist under the current working directory !"
#	  echo "Please copy the TAR file DBA_BUNDLE.tar to the current working directory and re-run the script."
#	  exit
#	fi

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
   echo "No Database is Running !"
   echo
   return
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
    echo "---------------------"
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
        if [ -z "${REPLY##[0-9]*}" ]
         then
          export ORACLE_SID=$DB_ID
	  echo
          echo "Selected Instance:"
	  echo "********"
          echo ${DB_ID}
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
  USR_ORA_HOME=`grep -i "^${ORA_USER}:" /etc/passwd| cut -f6 -d ':'|tail -1`
# USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

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
  ORACLE_HOME=`grep -v '^\#' ${ORATAB} | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' ${ORATAB} | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
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
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' ${USR_ORA_HOME}/.bash_profile ${USR_ORA_HOME}/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
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
DB_NAME_UPPER=`echo ${VAL1}| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
DB_NAME_LOWER=$( echo "${DB_NAME_UPPER}" | tr -s  '[:upper:]' '[:lower:]' )
export DB_NAME_UPPER
export DB_NAME_LOWER

# DB_NAME is Uppercase or Lowercase?:

     if [ -f $ORACLE_HOME/diagnostics/${DB_NAME_UPPER} ]
        then
                DB_NAME=${DB_NAME_UPPER}
        else
                DB_NAME=${DB_NAME_LOWER}
     fi

# #########################
# Getting ALERTLOG path:
# #########################
DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
ALERTZ=`echo ${DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
	if [ -f ${ALERTZ} ]
	 then
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log
	 else
DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT VALUE from V\$DIAG_INFO where name='Diag Trace';
exit;
EOF
)
ALERTZ=`echo ${DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log
	fi


# ########################
# Getting ORACLE_BASE:
# ########################

# Get ORACLE_BASE from user's profile if it EMPTY:

if [ -z "${ORACLE_BASE}" ]
 then
  ORACLE_BASE=`grep -h 'ORACLE_BASE=\/' $USR_ORA_HOME/.bash* $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_BASE
fi

# Setting the BUNDLE Environment:

PROFILE=${USR_ORA_HOME}/.DBA_BUNDLE_profile

        if [ -f ${USR_ORA_HOME}/.bashrc ]
         then
	  USRPROF=${USR_ORA_HOME}/.bashrc
	  sed '/DBA_BUNDLE/d' ${USRPROF} > ${USRPROF}.tmp && mv ${USRPROF}.tmp ${USRPROF}
          echo "# The Following Entry For DBA_BUNDLE Aliases" >> ${USRPROF}
	  echo ". ${PROFILE}" >> ${USRPROF}
	fi
	if [ -f ${USR_ORA_HOME}/.profile ]
	 then
	  USRPROF=${USR_ORA_HOME}/.profile
          sed '/DBA_BUNDLE/d' ${USRPROF} > ${USRPROF}.tmp && mv ${USRPROF}.tmp ${USRPROF}
          echo "# The Following Entry For DBA_BUNDLE Aliases" >> ${USRPROF}
          echo ". ${PROFILE}" >> ${USRPROF}
	fi
        if [ -f ${USR_ORA_HOME}/.bash_profile ]
	 then
          USRPROF=${USR_ORA_HOME}/.bash_profile
          sed '/DBA_BUNDLE/d' ${USRPROF} > ${USRPROF}.tmp && mv ${USRPROF}.tmp ${USRPROF}
          echo "# The Following Entry For DBA_BUNDLE Aliases" >> ${USRPROF}
          echo ". ${PROFILE}" >> ${USRPROF}
        fi

# ########################
# Getting GRID_HOME:
# ########################

CHECK_OCSSD=`ps -ef|grep 'ocssd.bin'|grep -v grep|wc -l`
CHECK_CRSD=`ps -ef|grep 'crsd.bin'|grep -v grep|wc -l`

    	if [ ${CHECK_OCSSD} -gt 0 ]
     then

GRID_HOME=`ps -ef|grep 'ocssd.bin'|grep -v grep|awk '{print $NF}'|sed -e 's/\/bin\/ocssd.bin//g'|grep -v sed|grep -v "//g"`
export GRID_HOME
    	fi

        if [ ${CHECK_CRSD} -gt 0 ]
        then

GRID_HOME=`ps -ef|grep 'ocssd.bin'|grep -v grep|awk '{print $NF}'|sed -e 's/\/bin\/ocssd.bin//g'|grep -v sed|grep -v "//g"`
export GRID_HOME
	fi

# #############################
# Getting hostname in lowercase:
# #############################
HOSTNAMELOWER=$( echo "`hostname --short`"| tr '[A-Z]' '[a-z]' )
export HOSTNAMELOWER

# ############################
# Locate clusterware log:
# ############################
# Locate ADR BASE:
VAL_ADR_BASE=$(${ORACLE_HOME}/bin/adrci <<EOF
exit;
EOF
)
ADR_BASE=`echo ${VAL_ADR_BASE}|awk '{print $(NF-1)}'|sed -e 's/"//g'`
export ADR_BASE

# Check for ocssd clusterware process:
CHECK_OCSSD=`ps -ef|grep 'ocssd.bin'|grep -v grep|wc -l`

if [ ${CHECK_OCSSD} -gt 0 ]
then

ALEGRACLOGFILE=`locate -i crs/${HOSTNAMELOWER}/crs/trace/alert.log`

# Locate Clusterware log location:
	if   [ -f ${ADR_BASE}/diag/crs/${HOSTNAMELOWER}/crs/trace/alert.log ]
	 then
RACLOGFILE="${ADR_BASE}/diag/crs/${HOSTNAMELOWER}/crs/trace/alert.log"
	elif [ -f ${ALEGRACLOGFILE} ]
	 then
RACLOGFILE=${ALEGRACLOGFILE}
	elif [ -f ${GRID_HOME}/log/${HOSTNAMELOWER}/alert${HOSTNAMELOWER}.log ]
	 then
RACLOGFILE="${GRID_HOME}/log/${HOSTNAMELOWER}/alert${HOSTNAMELOWER}.log"
	 else
RACLOGFILE="${GRID_HOME}/log/${HOSTNAMELOWER}/alert.log"
	fi

export RACLOGFILE

# ##############################
# Locate ASM instance alert log:
# ##############################

ASMALERTRAW=`ls -rtl \`locate alert_+ASM\`|tail -1|awk '{print $NF}'`

        if   [ -f ${ASMALERTRAW} ]
         then
ASMALERT=${ASMALERTRAW}
	fi

fi

# ##########################################
# Setting the Environment & Commands Aliases
# ##########################################
if [ -f ${USR_ORA_HOME}/${BUNDLE_NAME}/aliases_DBA_BUNDLE.sh ]
then
echo ""
echo "Setting Up Aliases..."

PATH=$PATH:$ORACLE_HOME/bin
export PATH
TNS_ADMIN=${ORACLE_HOME}/network/admin
export TNS_ADMIN
#sed -i '/${BUNDLE_NAME}/d' ${PROFILE}
        if [ -f ${PROFILE} ]; then
	 sed '/DBA_BUNDLE/d' ${PROFILE} > ${PROFILE}.tmp && mv ${PROFILE}.tmp ${PROFILE}
	fi
echo "# ${BUNDLE_NAME}  ====================================================================================="  >> ${PROFILE}
echo "# ${BUNDLE_NAME}  The Following ALIASES Are Added By aliases_DBA_BUNDLE.sh Script [Part of ${BUNDLE_NAME}]"  >> ${PROFILE}
echo "# ${BUNDLE_NAME}  ====================================================================================="  >> ${PROFILE}
echo "ORACLE_SID=${ORACLE_SID}       		#${BUNDLE_NAME}" >> ${PROFILE}
echo "export ORACLE_SID        			#${BUNDLE_NAME}" >> ${PROFILE}
echo "EDITOR=vi					#${BUNDLE_NAME}" >> ${PROFILE}
echo "export EDITOR				#${BUNDLE_NAME}" >> ${PROFILE}
echo "alias l='ls'             			#${BUNDLE_NAME}" >> ${PROFILE}
echo "alias d='date'           			#${BUNDLE_NAME} >> Display the date." >> ${PROFILE}
echo "alias df='df -h'         			#${BUNDLE_NAME}" >> ${PROFILE}
echo "alias top='top -c'       			#${BUNDLE_NAME}" >> ${PROFILE}
echo "alias ll='ls -rtlh'      			#${BUNDLE_NAME}" >> ${PROFILE}
echo "alias lla='ls -rtlha'    			#${BUNDLE_NAME}" >> ${PROFILE}
echo "alias cron='crontab -e'  			#${BUNDLE_NAME} >> Open the crontab for editing." >> ${PROFILE}
echo "alias crol='crontab -l'  			#${BUNDLE_NAME} >> Display the crontab." >> ${PROFILE}
echo "alias profile='. ${PROFILE}'        	#${BUNDLE_NAME} >> Call the user's profile to reload Environment Variables." >> ${PROFILE}
echo "alias viprofile='vi ${PROFILE}'     	#${BUNDLE_NAME} >> Open the user's profile for editing." >> ${PROFILE}
echo "alias catprofile='cat ${PROFILE}'   	#${BUNDLE_NAME} >> Display the user's profile." >> ${PROFILE}
echo "alias alert='tail -100f ${ALERTDB}' 	#${BUNDLE_NAME} >> Tail the default instance ALERTLOG file" >> ${PROFILE}
echo "alias vialert='view ${ALERTDB}'       	#${BUNDLE_NAME} >> Open the default instance ALERTLOG file" >> ${PROFILE}
echo "alias asmalert='tail -100f ${ASMALERT}'   #${BUNDLE_NAME} >> Tail the ASM instance ALERTLOG file" >> ${PROFILE}
echo "alias viasmalert='view ${ASMALERT}'       	#${BUNDLE_NAME} >> Open the ASM instance ALERTLOG file" >> ${PROFILE}
echo "alias sql='sqlplus "/ as sysdba" @${USR_ORA_HOME}/${BUNDLE_NAME}/login.sql.sav'     #${BUNDLE_NAME} >> Open the SQLPLUS console" >> ${PROFILE}
echo "alias grid='cd ${GRID_HOME}; ls; pwd' 	#${BUNDLE_NAME} >> Step under GRID_HOME if installed." >> ${PROFILE}
echo "alias oh='cd ${ORACLE_HOME};ls;pwd'               #${BUNDLE_NAME} >> Step under ORACLE_HOME." >> ${PROFILE}
echo "alias bundle=' cd ${USR_ORA_HOME}/${BUNDLE_NAME};. aliases_DBA_BUNDLE.sh;cd -' #${BUNDLE_NAME} >> Set the default Instance for BUNDLE Commands." >> ${PROFILE}
echo "alias bundledir=' cd ${USR_ORA_HOME}/${BUNDLE_NAME};pwd'			     #${BUNDLE_NAME} >> Step under Bundle directory." >> ${PROFILE}
echo "alias p='ps -ef|grep pmon|grep -v grep'           #${BUNDLE_NAME} >> List current RUNNING Instances." >> ${PROFILE}
echo "alias lsn='ps -ef|grep lsn|grep -v grep'          #${BUNDLE_NAME} >> List current RUNNING Listeners." >> ${PROFILE}
echo "alias bdump='cd ${ALERTZ};ls -lrth|tail -10;pwd'  #${BUNDLE_NAME} >> Step under bdump" >> ${PROFILE}
echo "alias dbs='cd ${ORACLE_HOME}/dbs;ls -rtlh;pwd'    #${BUNDLE_NAME} >> Step you under ORACLE_HOME/dbs directory." >> ${PROFILE}
echo "alias rman='${ORACLE_HOME}/bin/rman target /'     #${BUNDLE_NAME} >> Open the RMAN console" >> ${PROFILE}
echo "alias lis='vi ${ORACLE_HOME}/network/admin/listener.ora'              #${BUNDLE_NAME} >> Open the listener file" >> ${PROFILE}
echo "alias tns='vi ${ORACLE_HOME}/network/admin/tnsnames.ora'              #${BUNDLE_NAME} >> Open the tnsnames file" >> ${PROFILE}
echo "alias pfile='vi ${ORACLE_HOME}/dbs/init${ORACLE_SID}.ora'             #${BUNDLE_NAME} >> Open the pfile" >> ${PROFILE}
echo "alias aud='cd ${ORACLE_HOME}/rdbms/audit;ls -rtlh|tail -200'          #${BUNDLE_NAME} >> Step under the audit logs directory" >> ${PROFILE}
echo "alias network='cd ${ORACLE_HOME}/network/admin;ls -rtlh;pwd'          #${BUNDLE_NAME} >> Step under Oracle Network files directory" >> ${PROFILE}
echo "alias spfile='view ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora'        #${BUNDLE_NAME} >> Open the SPFILE" >> ${PROFILE}
echo "alias raclog='tail -100f ${RACLOGFILE}' 				    #${BUNDLE_NAME} >> Monitor Clusterware ALERTLOG on the fly." >> ${PROFILE}
echo "alias clusterwarelog='tail -100f ${RACLOGFILE}' 			    #${BUNDLE_NAME} >> Monitor Clusterware ALERTLOG on the fly." >> ${PROFILE}
echo "alias removebundle='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/bundle_remove.sh'  #${BUNDLE_NAME} >> Remove All Modifications done by aliases script." >> ${PROFILE}
echo "alias dfs='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/datafiles.sh'               #${BUNDLE_NAME} >> List All DATAFILES on the database." >> ${PROFILE}
echo "alias datafiles='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/datafiles.sh'         #${BUNDLE_NAME} >> List All DATAFILES on the database." >> ${PROFILE}
echo "alias invalid='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/invalid_objects.sh'     #${BUNDLE_NAME} >> List All Invalid Objects." >> ${PROFILE}
echo "alias objects='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/biggest_100_objects.sh' #${BUNDLE_NAME} >> List Biggest 100 Object on the database." >> ${PROFILE}
echo "alias lockuser='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/lock_user.sh'	    #${BUNDLE_NAME} >> lock a specific DB User Account." >> ${PROFILE}
echo "alias lock='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/lock_user.sh'         	    #${BUNDLE_NAME} >> lock a specific DB User Account." >> ${PROFILE}
echo "alias userlock='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/lock_user.sh'          #${BUNDLE_NAME} >> lock a specific DB User Account." >> ${PROFILE}
echo "alias unlockuser='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/unlock_user.sh'      #${BUNDLE_NAME} >> Unlock a specific DB User Account." >> ${PROFILE}
echo "alias userunlock='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/unlock_user.sh'      #${BUNDLE_NAME} >> Unlock a specific DB User Account." >> ${PROFILE}
echo "alias unlock='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/unlock_user.sh'     	    #${BUNDLE_NAME} >> Unlock a specific DB User Account." >> ${PROFILE}
echo "alias sessions='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/all_sessions_info.sh'  #${BUNDLE_NAME} >> List All current sessions on the DB." >> ${PROFILE}
echo "alias session='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/session_details.sh'     #${BUNDLE_NAME} >> List Details of a current session." >> ${PROFILE}
echo "alias activesessions='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/active_sessions.sh'     #${BUNDLE_NAME} >> List ALL ACTIVE Sessions." >> ${PROFILE}
echo "alias active='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/active_sessions.sh'     #${BUNDLE_NAME} >> List ALL ACTIVE Sessions." >> ${PROFILE}
echo "alias sess='sh /home/oracle/${BUNDLE_NAME}/all_sessions_info.sh|grep -v INACTIVE|grep -v Streams|grep -v \"Net message from client\"|grep -v \"class slave wait\"' #${BUNDLE_NAME} >> List Details of ACTIVE session." >> ${PROFILE}
echo "alias sid='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/session_details.sh'         #${BUNDLE_NAME} >> List Details of a current session." >> ${PROFILE}
echo "alias locks='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/db_locks.sh'              #${BUNDLE_NAME} >> Show Blocking LOCKS on the database" >> ${PROFILE}
echo "alias sqlid='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/sql_id_details.sh'        #${BUNDLE_NAME} >> Show a specific SQL Statmnt details." >> ${PROFILE}
echo "alias parm='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/parameter_val.sh'          #${BUNDLE_NAME} >> Show the value of a Visible/Hidden DB Parameter." >> ${PROFILE}
echo "alias jobs='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/db_jobs.sh'                #${BUNDLE_NAME} >> List All database Jobs." >> ${PROFILE}
echo "alias spid='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/process_info.sh'           #${BUNDLE_NAME} >> Show Session details providing its Unix PID." >> ${PROFILE}
echo "alias tbs='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/tablespaces.sh'             #${BUNDLE_NAME} >> List All TABLESPACES on the database." >> ${PROFILE}
echo "alias tablespaces='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/tablespaces.sh'     #${BUNDLE_NAME} >> List All TABLESPACES on the database." >> ${PROFILE}
echo "alias cleanup='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/oracle_cleanup.sh'      #${BUNDLE_NAME} >> Backup & Clean up All DB & its Listener LOGs." >> ${PROFILE}
echo "alias starttrace='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/start_tracing.sh'    #${BUNDLE_NAME} >> Start TRACING an Oracle Session." >> ${PROFILE}
echo "alias stoptrace='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/stop_tracing.sh'      #${BUNDLE_NAME} >> Stop TRACING a traced Oracle Session." >> ${PROFILE}
echo "alias objectddl='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/object_ddl.sh'        #${BUNDLE_NAME} >> Generate the Creation DDL Statement for an OBJECT." >> ${PROFILE}
echo "alias objectsize='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/object_size.sh'      #${BUNDLE_NAME} >> Show the size of an OBJECT." >> ${PROFILE}
echo "alias tablesize='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/object_size.sh'       #${BUNDLE_NAME} >> Show the size of an OBJECT." >> ${PROFILE}
echo "alias oradebug='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/oradebug.sh'           #${BUNDLE_NAME} >> Run ORADEBUG utility for hang analysis report." >> ${PROFILE}
echo "alias userddl='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/user_ddl.sh'            #${BUNDLE_NAME} >> Generate Full SQL Creation script for DB USER." >> ${PROFILE}
echo "alias userdetail='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/user_details.sh'     #${BUNDLE_NAME} >> Generate USER DDL plus Schema information." >> ${PROFILE}
echo "alias schemadetails='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/user_details.sh'  #${BUNDLE_NAME} >> Generate USER DDL plus Schema information." >> ${PROFILE}
echo "alias roleddl='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/role_ddl.sh'            #${BUNDLE_NAME} >> Generate Full SQL Creation script for DB ROLE." >> ${PROFILE}
echo "alias roledetail='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/role_ddl.sh'         #${BUNDLE_NAME} >> Generate Full SQL Creation script for DB ROLE." >> ${PROFILE}
echo "alias lastlogin='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/last_logon_report.sh' #${BUNDLE_NAME} >> Report the last login date for ALL users on DB." >> ${PROFILE}
echo "alias failedlogin='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/failed_logins.sh'   #${BUNDLE_NAME} >> Report the last failed login attempts on the DB." >> ${PROFILE}
echo "alias archivedel='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/Archives_Delete.sh'  #${BUNDLE_NAME} >> Delete Archivelogs older than n number of days through RMAN." >> ${PROFILE}
echo "alias analyze='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/analyze_tables.sh'      #${BUNDLE_NAME} >> Analyze All Tables in a Schema." >> ${PROFILE}
echo "alias audit='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/zAngA_zAngA.sh'           #${BUNDLE_NAME} >> Retrieve AUDIT data for a DB user on a SPECIFIC DATE." >> ${PROFILE}
echo "alias zanga='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/zAngA_zAngA.sh'           #${BUNDLE_NAME} >> Retrieve AUDIT data for a DB user on a SPECIFIC DATE." >> ${PROFILE}
echo "alias gather='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/gather_stats.sh'         #${BUNDLE_NAME} >> Backup & Gather Statistics for a SPECIFIC SCHEMA|TABLE." >> ${PROFILE}
echo "alias exportdata='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/export_data.sh'      #${BUNDLE_NAME} >> Export Database | SCHEMA | Table data with EXP or EXPDP." >> ${PROFILE}
echo "alias rmanfull='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/RMAN_full.sh'          #${BUNDLE_NAME} >> Takes an RMAN FULL DATABASE BACKUP." >> ${PROFILE}
echo "alias tableinfo='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/table_info.sh'        #${BUNDLE_NAME} >> Show ALL Important Information about specific TABLE." >> ${PROFILE}
echo "alias tablerebuild='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/rebuild_table.sh'  #${BUNDLE_NAME} >> REBUILD a TABLE and its related INDEXES." >> ${PROFILE}
echo "alias allusersddl='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/all_users_ddl.sh'   #${BUNDLE_NAME} >> Generate DDL Statement for all DB users." >> ${PROFILE}
echo "alias asmdisks='sh ${USR_ORA_HOME}/${BUNDLE_NAME}/asmdisks.sh'           #${BUNDLE_NAME} >> Show ASM Disks info, Mount points and Labels" >> ${PROFILE}

source ${PROFILE}

echo ""
echo "*******************"
echo "LIST OF ALL ALIASES:"
echo "*******************"
echo 
echo " ==============================================================="
echo "|Alias          |Usage                                          |"
echo "|===============|===============================================|"
echo "|alert          |Open the Database Alertlog with tail -f        |"
echo "|---------------|-----------------------------------------------|"
echo "|vialert        |Open the Database Alertlog with vi editor      |"
echo "|---------------|-----------------------------------------------|"
echo "|oh             |Go to ORACLE_HOME Dir                          |"
echo "|---------------|-----------------------------------------------|"
echo "|bundle         |Go to Bundle Dir and run aliases_DBA_BUNDLE.sh |"
echo "|---------------|-----------------------------------------------|"
echo "|removebundle   |Remove bundle Aliases from the System.         |"
echo "|---------------|-----------------------------------------------|"
echo "|p              |List Running Instances                         |"
echo "|---------------|-----------------------------------------------|"
echo "|lsn            |List Running Listeners                         |"
echo "|---------------|-----------------------------------------------|"
echo "|lis            |Open listener.ora file with vi editor          |"
echo "|---------------|-----------------------------------------------|"
echo "|tns            |Open tnsnames.ora file with vi editor          |"
echo "|---------------|-----------------------------------------------|"
echo "|pfile          |Open the Instance PFILE with vi editor         |"
echo "|---------------|-----------------------------------------------|"
echo "|spfile         |Open the Instance SPFILE with vi editor        |"
echo "|---------------|-----------------------------------------------|"
echo "|dbs            |Go to ORACLE_HOME/dbs                          |"
echo "|---------------|-----------------------------------------------|"
echo "|aud            |Go to ORACLE_HOME/rdbms/audit                  |"
echo "|---------------|-----------------------------------------------|"
echo "|bdump          |Go to BACKGROUND_DUMP_DEST                     |"
echo "|---------------|-----------------------------------------------|"
echo "|network        |Go to ORACLE_HOME/network/admin                |"
echo "|---------------|-----------------------------------------------|"
echo "|raclog         |Open the Clusterware Alertlog                  |"
echo "|---------------|-----------------------------------------------|"
echo "|dfs/datafiles  |List All DATAFILES on a database               |"
echo "|---------------|-----------------------------------------------|"
echo "|tbs/tablespaces|List All TABLESPACES on a database             |"
echo "|---------------|-----------------------------------------------|"
echo "|invalid        |List All Invalid Objects + Fix                 |"
echo "|---------------|-----------------------------------------------|"
echo "|objects        |List the Biggest 100 Objects in the database   |"
echo "|---------------|-----------------------------------------------|"
echo "|session/sid    |List Details of a current oracle session       |"
echo "|---------------|-----------------------------------------------|"
echo "|sessions       |List All current sessions details on RAC DB    |"
echo "|---------------|-----------------------------------------------|"
echo "|active         |List ACTIVE SESSIONS/Long activities on the DB |"
echo "|---------------|-----------------------------------------------|"
echo "|spid           |Show Session details Based on its Unix PID     |"
echo "|---------------|-----------------------------------------------|"
echo "|sqlid          |Show/Tune SQL Statement Based on its SQL_ID    |"
echo "|---------------|-----------------------------------------------|"
echo "|locks          |Show Blocking LOCKS on the database            |"
echo "|---------------|-----------------------------------------------|"
echo "|lockuser       |lock a specific DB User Account                |"
echo "|---------------|-----------------------------------------------|"
echo "|unlockuser     |Unlock a specific DB User Account              |"
echo "|---------------|-----------------------------------------------|"
echo "|parm           |Show a Visible/Hidden DB Parameter Value       |"
echo "|---------------|-----------------------------------------------|"
echo "|cleanup        |Backup & Clean up DBs & their Listener LOGs    |"
echo "|---------------|-----------------------------------------------|"
echo "|lastlogin      |Shows the last login date for ALL users on DB  |"
echo "|---------------|-----------------------------------------------|"
echo "|starttrace     |Start TRACING an Oracle Session                |"
echo "|---------------|-----------------------------------------------|"
echo "|stoptrace      |Stop TRACING a current Traced Oracle Session   |"
echo "|---------------|-----------------------------------------------|"
echo "|userddl        |Generate Full SQL Creation script for a DB User|"
echo "|---------------|-----------------------------------------------|"
echo "|schemadetails  |Generate USER DDL + Schema Information         |"
echo "|---------------|-----------------------------------------------|"
echo "|roleddl        |Generate Full SQL Creation script for a DB ROLE|"
echo "|---------------|-----------------------------------------------|"
echo "|objectddl      |Generate Full SQL Creation script for an Object|"
echo "|---------------|-----------------------------------------------|"
echo "|objectsize     |Show the size of an Object and its indexes     |"
echo "|---------------|-----------------------------------------------|"
echo "|failedlogin    |Report Failed Login Attempts in the last n days|"
echo "|---------------|-----------------------------------------------|"
echo "|archivedel     |Delete Archivelogs older than n number of days |"
echo "|---------------|-----------------------------------------------|"
echo "|analyze        |Analyze All tables in a specific SCHEMA        |"
echo "|---------------|-----------------------------------------------|"
echo "|audit/zanga    |Retrieve AUDIT data for DB users               |"
echo "|---------------|-----------------------------------------------|"
echo "|oradebug       |Run ORADEBUG utility for hang analysis report  |"
echo "|---------------|-----------------------------------------------|"
echo "|gather         |Gather STATISTICS on a SCHEMA or TABLE         |"
echo "|---------------|-----------------------------------------------|"
echo "|rmanfull       |Take RMAN FULL BACKUP for the database         |"
echo "|---------------|-----------------------------------------------|"
echo "|exportdata     |Export DB|SCHEMA|TABLE data using EXP or EXPDP |"
echo "|---------------|-----------------------------------------------|"
echo "|tableinfo      |Show Important Information for a specific TABLE|"
echo "|---------------|-----------------------------------------------|"
echo "|tablerebuild   |REBUILD A TABLE and its related INDEXES        |"
echo "|---------------|-----------------------------------------------|"
echo "|allusersddl    |Generate DDL[Creation & Privs] for ALL DB Users|"
echo "|---------------|-----------------------------------------------|"
echo "|asmdisks       |Show ASM Disks info, Mount Points and Labels   |"
echo " ==============================================================="	
echo ""
echo "The Following Scripts are WITHOUT Aliases:"
echo "******************************************"
echo " --------------------------------------------------------------------------------------------------- "
echo "|dbalarm.sh     |Monitors All Databases & Listeners ALERTLOGs for errors and locks along with       |"
echo "|               |monitoring the Tablespaces/ASM Diskgroups/CPU/Filesystems utilization.             |"
echo "|               |you have to Change this template <youremail@yourcompany.com> to your real E-mail   |"
echo "|               |Schedule this script in the crontab to run [every 5 minutes].                      |"
echo "|               |For More Details:                                                                  |"
echo "|               |http://dba-tips.blogspot.com/2014/02/database-monitoring-script-for-ora-and.html   |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|dbdailychk.sh  |Perform Database Health Check and send the report by Email you need to replace     |"
echo "|               |<youremail@yourcompany.com> template with your E-MAIL:                             |"
echo "|               |Health Checks include but not limited to:                                          |"
echo "|               |CHECK ALL DBs/Listeners ALERTLOGS FOR ERRORS                                       |"
echo "|               |CHECK Filesystem/CPU/Tablespaces utilization                                       |"
echo "|               |CHECK Unusable Indexes/Invalid Objects/Corrupted Blocks/Failed Jobs                |"
echo "|               |/Failed Logins/Active Incidents/DB Growth/Resource Limits/Restore Points/Advisors/ |"
echo "|               |Monitored Indexes/Redolog Switches/Modified Parameters/RMAN Backups/RAC Services/  |"
echo "|               |New Created Objects/Long Running Jobs/Audit Records                                |"
echo "|               |For More Details:                                                                  |"
echo "|               |http://dba-tips.blogspot.com/2015/05/oracle-database-health-check-script.html      |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|SHUTDOWN_All.sh|SHUTDOWN ALL running Databases and Listeners on The server                         |"
echo "|               |I didn't alias it, to avoid having it run accidentally!.                           |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|COLD_BACKUP.sh |-Take a COLD BACKUP for any database.                                              |"
echo "|               |-Create a Restore Script to help you restore that Cold Backup later.               |"
echo "|               |For More Details:                                                                  |"
echo "|               |http://dba-tips.blogspot.com/2014/02/cold-backup-script.html                       |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|schedule_rman_f|Can be scheduled in the crontab to take an RMAN Full backup for a specific database|"
echo "|ull_bkp.sh     |You MUST modify the variables/channels/maintenance section to match your env.      |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|schedule_rman_i|Can be scheduled in the crontab to take an RMAN Image/Copy for a specific database |"
echo "|mage_copy_bkp.s|You MUST modify the variables/channels/maintenance sections to match your env.     |"
echo "|h              |Why consider RMAN image backups in your backup strategy, check this link:          |"
echo "|               |http://dba-tips.blogspot.com/2011/11/switch-database-to-rman-copy-backup-and.html  |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|configuration_ |Collect configuration baseline data for OS and all running DATABASES.              |"
echo "|baseline.sh    |help you to track/rollback changes in your environment.                            |"
echo "|               |It's recommended to execute it once a month. For More Details:                     |"
echo "|               |http://dba-tips.blogspot.com/2016/12/configuration-baseline-script-for-linux.html  |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|delete_applied_|Deletes the applied archivelogs on a standby DB                                    |"
echo "|archives_on_sta|For More Details:                                                                  |"
echo "|ndby.sh        |http://dba-tips.blogspot.com/2017/01/script-to-delete-applied-archivelogs-on.html  |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|backup_ctrl_spf|Backup Controlfile as (Trace/RMAN BKP), Backup SPFILE and Generate AWR [optional]  |"
echo "|_AWR.sh        |This script can be scheduled in the crontab to run once a day. Script options/     |"
echo "|               |variables must be modified to match your environment.                              |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|kill_long_runni|Kill all queries running longer than 2.5 Hours(can be customized inside the script)|"
echo "|ng_queries.sh  |by specific modules (to be specified inside the script)                            |"
echo "|               |This script can be scheduled in the crontab. Script options/variables MUST be      |"
echo "|               |modified to setup the killing criteria that matches your requirements.             |"
echo "|               |For More Details:                                                                  |"
echo "|               |http://dba-tips.blogspot.com/2018/04/automatic-kill-of-long-running-sessions.html  |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|report_long_run|Report long running queries that ran by specific user.                             |"
echo "|ing_queries.sh |For More Details:                                                                  |"
echo "|               |http://dba-tips.blogspot.com/2018/04/report-long-running-queries-long-active.html  |"
echo "|---------------|-----------------------------------------------------------------------------------|"
echo "|check_standby_l|If you have a standby DB then you can use this script on Primary DB site to report |"
echo "|ag.sh          |to you any LAG happens between the primary and the standby DB.                     |"
echo "|               |The variables section at the top of the script must be populated by you to match   |"
echo "|               |your environment or the script will not be able to run.                            |"
echo "|               |This script can be scheduled in the crontab to run every 5 minutes.                |"
echo "|               |For more details on how to use this script:                                        |"
echo "|               |http://dba-tips.blogspot.ae/2017/11/shell-script-to-check-lag-sync-status.html     |"
echo " --------------------------------------------------------------------------------------------------- "
echo ""
echo "***************************************"
echo "Thanks for using DBA BUNDLE V4.3,"
echo "Mahmmoud ADEL | Oracle DBA"
echo -e "\033[32;5mdba-tips.blogspot.com\033[0m"
echo "***************************************"
echo ""

else
 echo "The Bundle directory ${USR_ORA_HOME}/${BUNDLE_NAME} is not exist!"
 echo "The DBA_BUNDLE Tar File MUST be extracted under the Oracle Owner Home Directory: ${USR_ORA_HOME}"
 echo ""
fi

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
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Do not live under a rock :-) Every month a new version of DBA_BUNDLE get released, download it by visiting:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# REPORT BUGS to: mahmmoudadel@hotmail.com
