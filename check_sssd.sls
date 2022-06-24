#
# Check that sssd is enabled and running.
#
check_sssd:
   service.running:
     - name: sssd.service
     - enable: True

# If sssd was up and running or it was successfully restarted then
# send a RESOLVE event to NimBUS to close any open alerts.
# This RESOLVE event should only be sent if sssd was marked as down/dead
# before the check. This is to save the admins the extra work to close
# alerts in NimBUS manually.
clear_error:
   cmd.run:
     - name: '/usr/bin/rm -f /tmp/sssd.dead;/local/bin/tecresolve.sh CHK_LNX_SSSD SALT "Service sssd.service was successfully started."'
     - require:
       - check_sssd
     - onlyif: '/usr/bin/test -e /tmp/sssd.dead'

# If the check_sssd state failed, then send an alert to NimBUS and
# create a state file that can be checked next time the state is run.
set_error:
   cmd.run:
     - name: '/usr/bin/touch /tmp/sssd.dead;/local/bin/tecerror.sh CHK_LNX_SSSD SALT "Service sssd.service was dead and it has been started."'
     - onchanges:
       - check_sssd
