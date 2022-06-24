#
# Check that rsyslog is enabled and running.
#
check_syslog:
   service.running:
     - name: rsyslog.service
     - enable: True

# If rsyslog was up and running or it was successfully restarted then
# send a RESOLVE event to NimBUS to close any open alerts.
# This RESOLVE event should only be sent if rsyslog was marked as down/dead
# before the check. This is to save the admins the extra work to close
# alerts in NimBUS manually.
clear_error:
   cmd.run:
     - name: '/usr/bin/rm -f /tmp/syslog.dead;/local/bin/tecresolve.sh CHK_LNX_SYSLOG SALT "Service syslog.service was successfully started."'
     - require:
       - check_syslog
     - onlyif: '/usr/bin/test -e /tmp/syslog.dead'

# If the check_syslog state failed, then send an alert to NimBUS and
# create a state file that can be checked next time the state is run.
set_error:
   cmd.run:
     - name: '/usr/bin/touch /tmp/syslog.dead;/local/bin/tecerror.sh CHK_LNX_SYSLOG SALT "Service syslog.service was dead and it has been started."'
     - onchanges:
       - check_syslog
