# ##############################################################################################
# Script to be used on crontab to schedule an RMAN Image/Copy Backup
VER="[1.1]"
# ##############################################################################################
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      01-10-17            #   #   # #   #  
#
# Modified:	02-10-17
#
#
#
# ##############################################################################################

# VARIABLES Section: [Must be Modified for each Env]
# #################

# Backup Location: [Replace /backup/rmancopy with the right backup location path]
export BACKUPLOC=/backup/rmancopy

# Backup Retention "In Days": [Backups older than this retention will be deleted]
export BKP_RETENTION=7

# Archives Deletion "In Days": [Archivelogs older than this retention will be deleted]
export ARCH_RETENTION=7

# INSTANCE Name: [Replace ${ORACLE_SID} with your instance SID]
export ORACLE_SID=${ORACLE_SID}

# ORACLE_HOME Location: [Replace ${ORACLE_HOME} with the right ORACLE_HOME path]
export ORACLE_HOME=${ORACLE_HOME}

# Backup LOG location:
export RMANLOG=${BACKUPLOC}/rmancopy.log

# Show the full DATE and TIME details in the backup log:
export NLS_DATE_FORMAT='DD-Mon-YYYY HH24:MI:SS'


# Append the date to the backup log for each script execution:
echo "----------------------------" >> ${RMANLOG}
date                                >> ${RMANLOG}
echo "----------------------------" >> ${RMANLOG}

# ###################
# RMAN SCRIPT Section:
# ###################
${ORACLE_HOME}/bin/rman target /  msglog=${RMANLOG} append <<EOF
# Configuration Section:
# ---------------------
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
#CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUPLOC}/%F';
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '${ORACLE_HOME}/dbs/snapcf_${ORACLE_SID}.f';
## Avoid Deleting archivelogs NOT yet applied on the standby: [When FORCE is not used]
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

# Maintenance Section:
# -------------------
## Crosscheck backups/copied to check for expired backups which are physically not available on the media:
#crosscheck backup completed before 'sysdate-${BKP_RETENTION}' device type disk;
#crosscheck copy completed   before 'sysdate-${BKP_RETENTION}' device type disk;
## Report & Delete Obsolete backups which don't meet the RETENTION POLICY:
#report obsolete RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
#DELETE NOPROMPT OBSOLETE RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
## Delete All EXPIRED backups/copies which are not physically available:
#DELETE NOPROMPT EXPIRED BACKUP COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
#DELETE NOPROMPT EXPIRED COPY   COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
## Crosscheck Archivelogs to avoid the backup failure:
#CHANGE ARCHIVELOG ALL CROSSCHECK;
#DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
## Delete Archivelogs older than ARCH_RETENTION days:
#DELETE NOPROMPT archivelog all completed before 'sysdate -${ARCH_RETENTION}';

# Image Copy Backup Script starts here: [Create Image Copy and recover it]
# -------------------------------------
run{
allocate channel F1 type disk format '${BACKUPLOC}/%U';
allocate channel F2 type disk format '${BACKUPLOC}/%U';
allocate channel F3 type disk format '${BACKUPLOC}/%U';
allocate channel F4 type disk format '${BACKUPLOC}/%U';
BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 FOR RECOVER OF COPY WITH TAG 'DB_COPY_UPDTD_BKP'
DATABASE FORMAT '${BACKUPLOC}/%d_%t_%s_%p';						# Incremental Level 1 Backup to recover the Image COPY.
RECOVER COPY OF DATABASE WITH TAG 'DB_COPY_UPDTD_BKP';					# Recover Image Copy with the Incr lvl1.
DELETE noprompt backup TAG 'DB_COPY_UPDTD_BKP';						# Delete [only] the incrmental bkp used for recovery.
#DELETE noprompt backup TAG 'arc_for_image_recovery' completed before 'sysdate-1';	# Delete Archive bkp for the previous recover.
DELETE noprompt copy   TAG 'ctrl_after_image_reco';					# Delete Controlfile bkp for the previous run.
#sql 'alter system archive log current';
#BACKUP as compressed backupset archivelog from time not backed up 1 times
#format '${BACKUPLOC}/arc_%d_%t_%s_%p' tag 'arc_for_image_recovery';				# Backup Archivelogs after the Image Copy..
BACKUP as copy current controlfile format '${BACKUPLOC}/ctl_%U' tag 'ctrl_after_image_reco';	# Controlfile Copy Backup.
sql "ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS ''${BACKUPLOC}/controlfile.trc'' reuse";	# Controlfile Trace Backup.
sql "create pfile=''${BACKUPLOC}/init${ORACLE_SID}.ora'' from spfile";				# Backup SPFILE.
}
EOF

