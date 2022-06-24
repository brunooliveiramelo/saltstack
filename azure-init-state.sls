# Create the datavg1 volume
make-pv-for-datavg1:
  lvm.pv_present:
    - name: /dev/sdc
    - onlyif: test -e /dev/sdc

make-datavg1:
  lvm.vg_present:
    - name: datavg1
    - devices: /dev/sdc
    - require:
      - make-pv-for-datavg1

# Create the logical volumes in datavg1
make-worklv:
  lvm.lv_present:
  - name: worklv
  - vgname: datavg1
  - size: 2G
  - require:
    - make-datavg1

make-locallv:
  lvm.lv_present:
  - name: locallv
  - vgname: datavg1
  - size: 2G
  - require:
    - make-datavg1

make-loglv:
  lvm.lv_present:
  - name: loglv
  - vgname: datavg1
  - size: 5G
  - require:
    - make-datavg1

make-logcorelv:
  lvm.lv_present:
  - name: logcorelv
  - vgname: datavg1
  - size: 5G
  - require:
    - make-datavg1

make-nimbuslv:
  lvm.lv_present:
  - name: nimbuslv
  - vgname: datavg1
  - size: 1536M
  - require:
    - make-datavg1

make-homelv:
  lvm.lv_present:
  - name: homelv
  - vgname: datavg1
  - size: 1G
  - require:
    - make-datavg1

# Create and mount file systems
create-work-fs:
  blockdev.formatted:
    - name: /dev/datavg1/worklv
    - fs_type: xfs
    - require:
      - make-worklv

mount-work-fs:
  mount.mounted:
    - name: /work
    - device: /dev/datavg1/worklv
    - fstype: xfs
    - mkmnt: True
    - pass_num: 2
    - persist: True
    - opts:
      - defaults
    - require:
      - create-work-fs

create-local-fs:
  blockdev.formatted:
    - name: /dev/datavg1/locallv
    - fs_type: xfs
    - require:
      - make-locallv

mount-local-fs:
  mount.mounted:
    - name: /local
    - device: /dev/datavg1/locallv
    - fstype: xfs
    - mkmnt: True
    - pass_num: 2
    - persist: True
    - opts:
      - defaults
    - require:
      - create-local-fs

create-log-fs:
  blockdev.formatted:
    - name: /dev/datavg1/loglv
    - fs_type: xfs
    - require:
      - make-loglv

mount-log-fs:
  mount.mounted:
    - name: /log
    - device: /dev/datavg1/loglv
    - fstype: xfs
    - mkmnt: True
    - pass_num: 2
    - persist: True
    - opts:
      - defaults
    - require:
      - create-log-fs

create-logcore-fs:
  blockdev.formatted:
    - name: /dev/datavg1/logcorelv
    - fs_type: xfs
    - require:
      - make-logcorelv

mount-logcore-fs:
  mount.mounted:
    - name: /log/core
    - device: /dev/datavg1/logcorelv
    - fstype: xfs
    - mkmnt: True
    - pass_num: 2
    - persist: True
    - opts:
      - defaults
    - require:
      - create-logcore-fs
    - cmd.run: /usr/bin/chmod 1777 /log/core

create-nimbus-fs:
  blockdev.formatted:
    - name: /dev/datavg1/nimbuslv
    - fs_type: xfs
    - require:
      - make-nimbuslv

mount-nimbus-fs:
  mount.mounted:
    - name: /work/nimbus
    - device: /dev/datavg1/nimbuslv
    - fstype: xfs
    - mkmnt: True
    - pass_num: 2
    - persist: True
    - opts:
      - defaults
    - require:
      - create-nimbus-fs

# Before we mount the home file system we must salvage what the is in the
# current /home directory.
save-oldhome:
  cmd.run:
    - name: '/usr/bin/tar -cvf /tmp/azure-init-oldhome.tar /home'
    - require:
      - make-homelv
    - unless: /usr/bin/df /home|/usr/bin/grep home

delete-oldhome:
  cmd.run:
    - name: '/usr/bin/rm -rf /home'
    - require:
      - save-oldhome
    - unless: /usr/bin/df /home|/usr/bin/grep home

# Create the home file system
create-home-fs:
  blockdev.formatted:
    - name: /dev/datavg1/homelv
    - fs_type: xfs
    - require:
      - make-homelv

# Mount /home
mount-home-fs:
  mount.mounted:
    - name: /home
    - device: /dev/datavg1/homelv
    - fstype: xfs
    - mkmnt: True
    - pass_num: 2
    - persist: True
    - opts:
      - defaults
    - require:
      - create-home-fs

restore-oldhome:
  cmd.run:
    - name: '/usr/bin/tar -xvf /tmp/azure-init-oldhome.tar'
    - cwd: /
    - require:
      - mount-home-fs
    - onlyif: ls /tmp/azure-init-oldhome.tar

delete-oldhome-tar:
  cmd.run:
    - name: '/usr/bin/rm -f /tmp/azure-init-oldhome.tar'
    - require:
      - restore-oldhome
    - onlyif: ls /tmp/azure-init-oldhome.tar


# The /home/sys NFS mount
home-sysman:
  mount.mounted:
    - name: /home/sys
    - device: sharedfs-p:/shared/home_sysman
    - fstype: nfs
    - mkmnt: True
    - pass_num: 0
    - dump: 0
    - persist: True
    - opts:
      - auto
      - mountproto=tcp
      - bg
      - hard
      - intr
      - rsize=16384
      - wsize=16384

# The /software NFS mount
software-rcompany:
  mount.mounted:
    - name: /software
    - device: sharedfs-p:/shared/software
    - fstype: nfs
    - mkmnt: True
    - pass_num: 0
    - dump: 0
    - persist: True
    - opts:
      - noauto
      - mountproto=tcp
      - ro
      - rsize=16384

# We must make sure that resolv.conf is set correctly with
# domain search and name servers.
# In SLES 15 this is done in /etc/sysconfig/network/config
/etc/sysconfig/network/config:
  file.managed:
    - source: salt://azure/etc/sysconfig/network/config._azure
    - user: root
    - group: root
    - mode: 644

# Register our hostname in DNS at boot
dns_update1:
  file.line:
    - name: /etc/sysconfig/network/ifcfg-eth0
    - mode: ensure
    - content: POST_UP_SCRIPT="compat:suse:nsupdate"
    - after: CLOUD_NETCONFIG_MANAGE*
    - backup: .bak

# And the script that actually does the registering.
dns_update2:
  file.managed:
    - name: /etc/sysconfig/network/scripts/nsupdate
    - source: salt://azure/etc/sysconfig/network/scripts/nsupdate
    - user: root
    - group: root
    - mode: 744

# Add company SLES rcompanysitory and refresh rcompanys
company-rcompanys:
  file.managed:
    - name: /etc/zypp/rcompanys.d/SLES-12-x86_64-company_V1.0.rcompany
    - source: salt://azure/etc/zypp/rcompanys.d/SLES-12-x86_64-company_V1.0.rcompany._azure
    - user: root
    - group: root
    - mode: 644
  cmd.run:
    - name: /usr/bin/zypper -n --no-gpg-checks --gpg-auto-import-keys refresh
    - onchanges:
      - file: /etc/zypp/rcompanys.d/SLES-12-x86_64-company_V1.0.rcompany

# Some changes to the config of zypper
# We don't want the check for deleted files at the end of a zypper command
"/usr/bin/sed -i 's/#  psCheckAccessDeleted = yes/psCheckAccessDeleted = no/g' /etc/zypp/zypper.conf":
  cmd.run:
    - onlyif: /usr/bin/grep "#  psCheckAccessDeleted = yes" /etc/zypp/zypper.conf

# We don't want recommended software to be installed. Only required.
"/usr/bin/sed -i 's/# solver.onlyRequires = false/solver.onlyRequires = true/g' /etc/zypp/zypp.conf":
  cmd.run:
    - onlyif: /usr/bin/grep "# solver.onlyRequires = false" /etc/zypp/zypp.conf

# Run zypper up
# We just did a refresh so that is not needed here.
'/usr/bin/zypper -n --no-refresh up':
    cmd.run

# We will probably have two kernels installed now. We shall purge the oldest
purge-kernels:
  file.replace:
    - name: /etc/zypp/zypp.conf
    - pattern: latest-1,running
    - repl: ''
    - backup: .bak1
  cmd.run:
    - name: /usr/bin/zypper -n purge-kernels --details
    - onchanges:
      - /etc/zypp/zypp.conf

# Copyback the original zypp.conf
'/usr/bin/mv /etc/zypp/zypp.conf.bak1 /etc/zypp/zypp.conf':
  cmd.run:
    - onlyif: ls /etc/zypp/zypp.conf.bak1

install-SUSE-packages:
  pkg.installed:
    - install_recommends: False
    - refresh: False
    - pkgs:
      - sssd
      - sssd-ldap
      - insserv-compat
      - clamav
      - net-tools-deprecated
      - at
      - ganglia-gmond
      - libganglia

# Enable sssd
enable-sssd:
  service.enabled:
    - name: sssd
    - enable: True

# Enable at
enable-at:
  service.enabled:
    - name: atd
    - enable: True

# Needs special treatment (sigh)
company-sssd-config:
  pkg.downloaded:
    - name: company_ConfigureSSSD

# Now we install the package we downloaded using rpm and the --force option.
# This is needed because /etc/sssd/sssd.conf conflicts with another package.
# Please note the wildcard in the name, the versionmight change over time.
# Please note the watch on the config file to restart sssd
install-company_ConfigureSSSD:
  cmd.run:
    - name: /usr/bin/rpm -ivh --force "/var/cache/zypp/packages/SLES-12-x86_64-company V1.0/RPMS/noarch/company_ConfigureSSSD-*.noarch.rpm"
    - require:
      - company-sssd-config
    - unless: rpm -q company_ConfigureSSSD
    - service.running:
      - name: sssd
      - enable: True
      - watch:
        - file: /etc/sssd/sssd.conf
    - service.running:
      - name: nscd
      - enable: True
      - watch:
        - file: /etc/nsswitch.conf

#
# We need some directory structure for the NimBUS Robot
# This is only needed to allow file distribution to put the
# diskmon_util.cfg file there before SMET deploys the master
# package
create-nimbus-structure:
  file.directory:
    - name: /work/nimbus/probes/sermon/diskmon_util
    - user: root
    - group: root
    - mode: 700
    - makedirs: True
    - recurse:
      - user
      - group
      - mode

# More company packages, fortunately without special treatment.
install-company-packages:
  pkg.installed:
    - install_recommends: False
    - refresh: False
    - pkgs:
      - company_NimBUSRobot
      - company_ConfigureTHP
      - company_Cron4All
      - company_ISDBDataCollection
      - company_logp
      - company_VIRUS
      - company_Set_cron.daily_time
      - company_ConfigureTHP

# We will now lock the company_NimBUSRobot package.
# SMET are responsble for updates.
lock-nimBUS:
  cmd.run:
    - name: /usr/bin/zypper -n addlock company_NimBUSRobot

# Our environment.
/etc/profile.local:
  file.managed:
    - source: salt://etc/profile_local/profile.local
    - user: root
    - group: root
    - mode: 755

# Fill /etc/node_descr.txt with default values unless it already exists.
'printf "Status        : <BUILD>\nEnvironment   : <Dev|Test|Intg|OSA|UAT|Prod|I0>\nApplication(s): \nOwners/Users  : " > /etc/node_descr.txt':
  cmd.run:
    - unless: ls /etc/node_descr.txt

# Empty /etc/motd
'/usr/bin/cat /dev/null > /etc/motd':
  cmd.run:
    - onlyif: /usr/bin/grep waagent /etc/motd

# Create /log/histfiles
/log/histfiles:
  file.directory:
    - owner: root
    - group: root
    - dir_mode: 1733

/etc/issue:
  file.managed:
    - source: salt://etc/issue/issue
    - user: root
    - group: root
    - mode: 644

/etc/issue.net:
  file.managed:
    - source: salt://etc/issue/issue.net
    - user: root
    - group: root
    - mode: 644

/etc/issue.warn:
  file.managed:
    - source: salt://etc/issue/issue.warn
    - user: root
    - group: root
    - mode: 644

/etc/ssh/issue.warn:
  file.managed:
    - source: salt://azure/etc/ssh/issue.warn
    - user: root
    - group: root
    - mode: 644

/etc/ssh/sshd_config:
  file.managed:
    - source: salt://azure/etc/ssh/sshd_config
    - user: root
    - group: root
    - mode: 640
    - unless: /usr/bin/grep company_MODIFIED /etc/ssh/sshd_config
  cmd.run:
    - name: /usr/bin/systemctl restart sshd
    - onchanges:
      - file: /etc/ssh/sshd_config

# Use our own time servers
/etc/chrony.d/azure.conf:
  file.absent

/etc/chrony.d/pool.conf:
  file.absent

/etc/chrony.d/company.conf:
  file.managed:
    - source: salt://azure/etc/chrony.d/company.conf
    - user: root
    - group: root
    - mode: 640
  service.running:
    - name: chronyd.service
    - enable: True
    - watch:
      - file: /etc/chrony.d/company.conf

# Fix postfix
# Make sure postfix is restarted if we change the config.
# The command to run when the /etc/sysconfig/postfix file is changed.
postfix0:
  cmd.run:
    - name: /usr/sbin/config.postfix
    - success_retcodes: 1
    - onchanges:
      - /etc/sysconfig/postfix

# Restart postfix. The order of this and the previous state is important.
# The restart of the postfix daemon should only happen after the command
# in postfix0 has been run.
postfix1:
  service.running:
    - name: postfix.service
    - enable: True
    - require:
      - postfix0
    - watch:
      - file: /etc/sysconfig/postfix

postfix2:
  file.replace:
    - name: /etc/sysconfig/postfix
    - pattern: POSTFIX_RELAYHOST=""
    - repl: POSTFIX_RELAYHOST="[smtpmail.internal.company.org]"
    - backup: .bak1

postfix3:
  file.replace:
    - name: /etc/sysconfig/postfix
    - pattern: POSTFIX_MYHOSTNAME=""
    - repl: POSTFIX_MYHOSTNAME="$(hostname)"
    - backup: .bak2

postfix4:
  file.replace:
    - name: /etc/sysconfig/postfix
    - pattern: POSTFIX_ADD_MAILBOX_SIZE_LIMIT="0"
    - repl: POSTFIX_ADD_MAILBOX_SIZE_LIMIT="102400000"
    - backup: .bak3

postfix5:
  file.replace:
    - name: /etc/sysconfig/postfix
    - pattern: POSTFIX_ADD_MESSAGE_SIZE_LIMIT="0"
    - repl: POSTFIX_ADD_MESSAGE_SIZE_LIMIT="15360000"
    - backup: .bak4

# Hardware lock elision
hle:
  file.append:
    - name: /etc/ld.so.conf.d/noelision.conf
    - text: /lib64/noelision

# Configure kdump
kdump1:
  file.replace:
    - name: /etc/default/grub
    - pattern: |
        ^(GRUB_CMDLINE_LINUX_DEFAULT=")(.+)"$
    - repl: '\1\2 crashkernel=512M-3G:128M,3G-13G:256M,13G-49G:384M,49G-:768M"\n'
    - backup: .bak
    - unless: "grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=.+crashkernel' /etc/default/grub"
  cmd.run:
    - name: "grub2-mkconfig -o /boot/grub2/grub.cfg"
    - onchanges:
      - /etc/default/grub

kdump2:
  file.replace:
    - name: /etc/sysconfig/kdump
    - pattern: KDUMP_NETCONFIG="auto"
    - repl: KDUMP_NETCONFIG="eth0:dhcp"
    - backup: .bak1

kdump3:
  file.replace:
    - name: /etc/sysconfig/kdump
    - pattern: KDUMP_SAVEDIR="file:///var/crash"
    - repl: KDUMP_SAVEDIR="nfs://kdump.internal.company.org/shared/kernel_dumps"
    - backup: .bak2

# Normally we should create a kdump init RAM disk, but as we don't have
# memory reserved for kdump yet, the creation of the RAM disk will generate an
# error. Instead we will make sure that no kdump RAM disk exists so that
# it can be created at the next boot.
kdump4:
  cmd.run:
    - name: /usr/bin/rm -f $(kdumptool find_kernel |awk '/^Initrd:/ { print $NF}')

# Make sure journald is restarted if we change the config.
journal0:
  service.running:
    - name: systemd-journald
    - enable: True
    - watch:
      - file: /etc/systemd/journald.conf

journal1:
  cmd.run:
    - name: mkdir -p /var/log/journal
    - unless: test -d /var/log/journal

journal2:
  file.replace:
    - name: /etc/systemd/journald.conf
    - pattern: '^#Storage=.*'
    - repl: "Storage=auto"
    - require:
      - journal1

journal3:
  file.replace:
    - name: /etc/systemd/journald.conf
    - pattern: '^#SystemMaxUse=.*'
    - repl: "SystemMaxUse=256M"
    - require:
      - journal1

journal4:
  file.replace:
    - name: /etc/systemd/journald.conf
    - pattern: '^#SystemKeepFree=.*'
    - repl: "SystemKeepFree=25%"
    - require:
      - journal1

journal5:
  file.replace:
    - name: /etc/systemd/journald.conf
    - pattern: '^#SystemMaxFilesSize=.*'
    - repl: "SystemMaxFileSize=10M"
    - require:
      - journal1

journal6:
  file.replace:
    - name: /etc/systemd/journald.conf
    - pattern: '^#SystemMaxFiles=.*'
    - repl: "SystemMaxFiles=24"
    - require:
      - journal1

journal7:
  file.replace:
    - name: /etc/systemd/journald.conf
    - pattern: '^#MaxRetentionSec=.*'
    - repl: "MaxRetentionSec=1 month"
    - require:
      - journal1

# Set-up swap space
# The azure VMs always come with a "temporary" ephemeral disk. We can use this
# disk as swap space. By degaultit is formatted with ext4 and mounted on /mnt
# So we need to unmount the disk and reformat the disk and then activate
# the swap space
create-swap1:
  mount.unmounted:
    - name: /mnt
    - persist: True

create-swap2:
  cmd.run:
    - name: /sbin/mkswap -f /dev/sdb
    - unless: /sbin/swaplabel /dev/sdb
    - require:
      - create-swap1

create-swap3:
  mount.swap:
    - name: /dev/sdb
    - persist: True
    - require:
      - create-swap2

# The azure cloud has an omsagent running on the server. It makes use
# of a drop-in sudoers file in /etc/sudoers.d. The company_ConfigureSSSD package
# empties /etc/sudoers completely. We need to put the necessary line back in.
azure-sudoers:
  file.append:
    - name: /etc/sudoers
    - text: '#includedir /etc/sudoers.d'

# Get rid of the Azure admin user, we don't need it after this
# salt state has been applied.
rem_az_admin:
  user.absent:
    - name: lazdev
    - purge: yes

# Disable ipv6
ipv6_1:
  sysctl.present:
    - name: net.ipv6.conf.all.disable_ipv6
    - value: 1
    - config: /etc/sysctl.d/65-azure.conf

ipv6_2:
  sysctl.present:
    - name: net.ipv6.conf.default.disable_ipv6
    - value: 1
    - config: /etc/sysctl.d/65-azure.conf

ipv6_3:
  sysctl.present:
    - name: net.ipv6.conf.lo.disable_ipv6
    - value: 1
    - config: /etc/sysctl.d/65-azure.conf

# Finally set grains to show that this is a cloud server and that it is
# in the Azure cloud
azure:
  grains.present:
    - name: site
    - force: true
    - value:
      - cloud
      - azure

# Reboot to force kdump generation and
# registering on name in DNS
reboot:
  cmd.run:
    - name: systemctl reboot
