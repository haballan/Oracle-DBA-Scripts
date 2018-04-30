# ##############################################################################################
# Script to be used on the crontab to schedule an RMAN Full Backup
VER="[1.1]"
# ##############################################################################################
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      04-10-17            #   #   # #   #  
#
# Modified:
#
#
#
# ##############################################################################################

# ##############################################################
# VARIABLES To be Modified by the user to match the Environment:
# ##############################################################

# INSTANCE Name: [Replace ${ORACLE_SID} with your instance SID]
ORACLE_SID=${ORACLE_SID}

# ORACLE_HOME Location: [Replace ${ORACLE_HOME} with the right ORACLE_HOME path]
ORACLE_HOME=${ORACLE_HOME}

# Backup Location: [Replace /backup/rmanfull with the backup location path]
BACKUPLOC=/backup/rmanfull

# COMPRESSED BACKUP option:[Y|N] [Default ENABLED]
COMPRESSION=Y

# Perform Maintenance: [Y|N] [Default ENABLED]
MAINTENANCEFLAG=Y

# Backup Retention "In Days": [Backups older than this retention will be deleted]
BKP_RETENTION=7

# Archives Deletion "In Days": [Archivelogs older than this retention will be deleted]
ARCH_RETENTION=7

# ##################
# GENERIC VARIABLES: [Can be left without modification]
# ##################

# MAX BACKUP Piece Size: [Must be BIGGER than the size of the biggest datafile in the database]
MAX_BKP_PIECE_SIZE=33g

# Backup LOG location:
RMANLOG=${BACKUPLOC}/rmanfull.log

# Show the full DATE and TIME details in the backup log:
NLS_DATE_FORMAT='DD-Mon-YYYY HH24:MI:SS'

export ORACLE_SID
export ORACLE_HOME
export BACKUPLOC
export COMPRESSION
export BKP_RETENTION
export ARCH_RETENTION
export MAX_BKP_PIECE_SIZE
export RMANLOG
export NLS_DATE_FORMAT
export MAINTENANCEFLAG

# Check the selected COMPRESSION option:
	case ${COMPRESSION} in
	Y|y|YES|Yes|yes|ON|on)
	COMPRESSED_BKP="AS COMPRESSED BACKUPSET"
	export COMPRESSED_BKP
	*)
	COMPRESSED_BKP=""
	export COMPRESSED_BKP
	esac

# Check the selected MAINTENANCE option:
        case ${MAINTENANCEFLAG} in
        Y|y|YES|Yes|yes|ON|on)
        HASH_MAINT=""
        export HASH_MAINT
        *)
        HASH_MAINT="#"
        export COMPRESSED_BKP
        esac


# Append the date to the backup log for each script execution:
echo "----------------------------" >> ${RMANLOG}
date                                >> ${RMANLOG}
echo "----------------------------" >> ${RMANLOG}

# ###################
# RMAN SCRIPT Section:
# ###################

${ORACLE_HOME}/bin/rman target /  msglog=${RMANLOG} append | tee ${RMANLOG}.tee <<EOF
# Configuration Section:
# ---------------------
${HASH_MAINT}CONFIGURE BACKUP OPTIMIZATION ON;
${HASH_MAINT}CONFIGURE CONTROLFILE AUTOBACKUP ON;
${HASH_MAINT}CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUPLOC}/%F';
${HASH_MAINT}CONFIGURE SNAPSHOT CONTROLFILE NAME TO '${ORACLE_HOME}/dbs/snapcf_${ORACLE_SID}.f';
## Avoid Deleting archivelogs NOT yet applied on the standby: [When FORCE is not used]
#CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

# Maintenance Section:
# -------------------
## Crosscheck backups/copied to check for expired backups which are physically not available on the media:
${HASH_MAINT}crosscheck backup completed before 'sysdate-${BKP_RETENTION}' device type disk;
${HASH_MAINT}crosscheck copy completed   before 'sysdate-${BKP_RETENTION}' device type disk;
## Report & Delete Obsolete backups which don't meet the RETENTION POLICY:
${HASH_MAINT}REPORT OBSOLETE RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
${HASH_MAINT}DELETE NOPROMPT OBSOLETE RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
## Delete All EXPIRED backups/copies which are not physically available:
${HASH_MAINT}DELETE NOPROMPT EXPIRED BACKUP COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
${HASH_MAINT}DELETE NOPROMPT EXPIRED COPY   COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
## Crosscheck Archivelogs to avoid the backup failure:
${HASH_MAINT}CHANGE ARCHIVELOG ALL CROSSCHECK;
${HASH_MAINT}DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
## Delete Archivelogs older than ARCH_RETENTION days:
${HASH_MAINT}DELETE NOPROMPT archivelog all completed before 'sysdate -${ARCH_RETENTION}';

# Full Backup Script starts here: [Compressed+Controlfile+Archives]
# ------------------------------
run{
allocate channel F1 type disk;
allocate channel F2 type disk;
allocate channel F3 type disk;
allocate channel F4 type disk;
sql 'alter system archive log current';
BACKUP ${COMPRESSED_BKP}
MAXSETSIZE ${MAX_BKP_PIECE_SIZE}
NOT BACKED UP SINCE TIME 'SYSDATE-2/24'
INCREMENTAL LEVEL=0
FORMAT '${BACKUPLOC}/%d_%t_%s_%p.bkp' 
FILESPERSET 100
TAG='FULLBKP'
DATABASE include current controlfile PLUS ARCHIVELOG NOT BACKED UP SINCE TIME 'SYSDATE-2/24';
## Backup the controlfile separately:
BACKUP ${COMPRESSED_BKP} CURRENT CONTROLFILE FORMAT '${BACKUPLOC}/CONTROLFILE_%d_%I_%t_%s_%p.bkp' TAG='CONTROLFILE_BKP' REUSE ;
## Trace backup of Controlfile & SPFILE:
SQL "ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS ''${BACKUPLOC}/controlfile.trc'' REUSE";
SQL "CREATE PFILE=''${BACKUPLOC}/init${ORACLE_SID}.ora'' FROM SPFILE";
}
EOF

