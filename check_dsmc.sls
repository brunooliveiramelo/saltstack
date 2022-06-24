#
# Check that dsmc is enabled and running.
#

check_dsmc_proc:
   status.process:
     - name: dsmc
     - onfail:
         - set_error

check_dsmc:
   service.running:
     - name: dsmc.service
     - enable: True


# If dsmc was up and running or it was successfully restarted then
# send a RESOLVE event to NimBUS to close any open alerts.
# This RESOLVE event should only be sent if dsmc was marked as down/dead
# before the check. This is to save the admins the extra work to close
# alerts in NimBUS manually.
clear_error:
   cmd.run:
     - name: '/usr/bin/rm -f /tmp/dsmc.dead;/local/bin/tecresolve.sh CHK_LNX_DSMC SALT "Service dsmc.service was successfully started."'
     - require:
       - check_dsmc
     - onlyif: '/usr/bin/test -e /tmp/dsmc.dead'

# If the check_dsmc state failed, then send an alert to NimBUS and
# create a state file that can be checked next time the state is run.
set_error:
   cmd.run:
     - name: '/usr/bin/touch /tmp/dsmc.dead;/local/bin/tecerror.sh CHK_LNX_DSMC SALT "Service dsmc.service was dead and it has been started."'
     - onchanges:
       - check_dsmc
