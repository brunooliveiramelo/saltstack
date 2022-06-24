# create logical volumes in datavg1
make-lvwork-filebeat:
    lvm.lv_present:
    - name: lvwork-filebeat
    - vgname: datavg1
    - size: 200M

make-lvlog-filebeat:
    lvm.lv_present:
    - name: lvlog-filebeat
    - vgname: datavg1
    - size: 200M

# create directory
create-workdir-filebeat:
    file.directory:
    - name: /work/filebeat
    - user: root
    - group: epousers
    - mode: 755
    - makedirs: True
    - recurse:
        - user
        - group
        - mode

create-logdir-filebeat:
    file.directory:
    - name: /log/filebeat
    - user: root
    - group: epousers
    - mode: 755
    - makedirs: True
    - recurse:
        - user
        - group
        - mode


# create and mount file systems
create-lvwork-filebeat:
    blockdev.formatted:
    - name: /dev/datavg1/lvwork-filebeat
    - fs_type: xfs
    - require:
        - make-lvwork-filebeat
        - create-workdir-filebeat

mount-lvwork-filebeat:
    mount.mounted:
    - name: /work/filebeat
    - device: /dev/datavg1/lvwork-filebeat
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
    - name: /dev/datavg1/lvwork-filebeat
    - fs_type: xfs
    - require: 
        - make-lvlog-filebeat
        - create-logdir-filebeat

mount-lvlog-filebeat:
    mount-mounted:
    - name: /log/filebeat
    - device: /dev/datavg1/lvlog-filebeat
    - fstype: xfs
    - mkmnt: 
    - pass_num: 2
    - dump: 1
    - persist: True
    - opts:
        - defaults
    - require:
        - create-lvlog-filebeat

# stop the filebeat service
stop-filebeat:
    service.dead:
    - name: filebeat

# copy the source filbeat to the new directory
# and the log directory to new structure
move-work-directory-filebeat:
    cmd.run:
    - name: /usr/bin/cp -r /work/etc /work/filebeat
    - require:
        - create-workdir-filebeat

move-usr-directory-filebeat:
    cmd.run:
    - name: /usr/bin/cp -r /work/usr /work/filebeat
    - require:
        - create-workdir-filebeat

move-log-directory-filebeat:
    cmd.run:
    - name: /usr/bin/cp -r /work/etc/log/filebeat /log/filebeat
    - require:
        - create-logdir-filebeat

# change filebeat.service
change-filebeat-service:
    file.managed:
        - name: /etc/systemd/system/filebeat.service
        - source: salt://bruno/filebeat-changedir-installation-state/etc/osa/filebeat.service
        - user: root
        - group: root
        - mode: 644
    cmd.run:
        - name: systemctl daemon-reload
        - onchanges:
            - file: /etc/systemd/system/filebeat.service

# start the filbebeat service
start-filebeat:
    service.enabled:
        - name: filebeat
        - enable: True
        - watch:
            - file: /etc/systemd/system/filebeat.service

