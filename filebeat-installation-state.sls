# create logical volumes in datavg1
# for the new work and log filebeat directory
make-lvwork-filebeat:
    lvm.lv_present:
    - name: lvwork_filebeat
    - vgname: datavg1
    - size: 400MB
    - unless:
        - /usr/sbin/lvdisplay /dev/datavg1/lvwork_filebeat

make-lvlog-filebeat:
    lvm.lv_present:
    - name: lvlog_filebeat
    - vgname: datavg1
    - size: 200M
    - unless:
        - /usr/sbin/lvdisplay /dev/datavg1/lvlog_filebeat

# create directory
create-workdir-filebeat:
    file.directory:
    - name: /work/filebeat
    - user: elk_t
    - group: companyusers
    - mode: 755
    - makedirs: True
    - recurse:
        - user
        - group
        - mode

create-logdir-filebeat:
    file.directory:
    - name: /log/filebeat
    - user: elk_t
    - group: companyusers
    - mode: 755
    - makedirs: True
    - recurse:
        - user
        - group
        - mode


# create and mount file systems
create-lvwork-filebeat:
    blockdev.formatted:
    - name: /dev/datavg1/lvwork_filebeat
    - fs_type: xfs
    - require:
        - make-lvwork-filebeat
        - create-workdir-filebeat

mount-lvwork-filebeat:
    mount.mounted:
    - name: /work/filebeat
    - device: /dev/datavg1/lvwork_filebeat
    - fstype: xfs
    - mkmnt: 
    - pass_num: 2
    - dump: 1
    - persist: True
    - opts:
        - defaults
    - require:
        - create-lvwork-filebeat

create-lvlog-filebeat:
    blockdev.formatted:
    - name: /dev/datavg1/lvlog_filebeat
    - fs_type: xfs
    - require: 
        - make-lvlog-filebeat
        - create-logdir-filebeat
  
mount-lvlog-filebeat:
    mount.mounted:
    - name: /log/filebeat
    - device: /dev/datavg1/lvlog_filebeat
    - fstype: xfs
    - mkmnt: 
    - pass_num: 2
    - dump: 1
    - persist: True
    - opts:
        - defaults
    - require:
        - create-lvlog-filebeat

# Ensure software is mounted
mount-software:
  cmd.run:
    - name: /usr/bin/mount /software
    - unless: /usr/bin/ls -lhd /software/filebeat/


# installing filebeat from rpm
install-filebeat-7.17.3:
    cmd.run:
     - name: /usr/bin/rpm -ivh --prefix=/work/filebeat /software/filebeat/filebeat-7.17.3-x86_64.rpm
     - require:
        - create-workdir-filebeat
        - mount-software
     - unless: /usr/bin/ls /work/filebeat/usr/share/filebeat/bin/filebeat

# change filebeat.service
change-filebeat-service:
    file.managed:
        - name: /etc/systemd/system/filebeat.service
        - source: salt://bruno/filebeat-installation-state/test/filebeat.service
        - user: root
        - group: root
        - mode: 644
        - require:
          - install-filebeat-7.17.3
    cmd.run:
        - name: systemctl daemon-reload
        - onchanges:
            - file: /etc/systemd/system/filebeat.service

# stop/ensure filebeat service is stopped
stop-filebeat:
    service.dead:
    - name: filebeat
    
