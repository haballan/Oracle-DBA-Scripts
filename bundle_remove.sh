###################################################
# ROLLBACK the work done by aliases_DBA_BUNDLE.sh
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      03-06-2014          #   #   # #   #
#
###################################################
CURR_USER=`whoami`
USR_ORA_HOME=`grep ${CURR_USER} /etc/passwd| cut -f6 -d ':'|tail -1`
rm -f ${USR_ORA_HOME}/.DBA_BUNDLE_profile

        if [ -f ${USR_ORA_HOME}/.bashrc ]
         then
          USRPROF=${USR_ORA_HOME}/.bashrc
          sed '/DBA_BUNDLE/d' ${USRPROF} > ${USRPROF}.tmp && mv ${USRPROF}.tmp ${USRPROF}
        fi
        if [ -f ${USR_ORA_HOME}/.profile ]
         then
          USRPROF=${USR_ORA_HOME}/.profile
          sed '/DBA_BUNDLE/d' ${USRPROF} > ${USRPROF}.tmp && mv ${USRPROF}.tmp ${USRPROF}
        fi
        if [ -f ${USR_ORA_HOME}/.bash_profile ]        
         then
          USRPROF=${USR_ORA_HOME}/.bash_profile        
          sed '/DBA_BUNDLE/d' ${USRPROF} > ${USRPROF}.tmp && mv ${USRPROF}.tmp ${USRPROF}
        fi
echo
echo 'The BUNDLE profie has been removed successfully from your system.'
echo "If you didn't like the bundle kindly write to me on: mahmmoudadel@hotmail.com"
echo
