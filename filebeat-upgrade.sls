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

# create new work and log directory
create-workdir-filebeat:
    file.directory:
    - name: /work/filebeat
    - user: mongo_o
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
    - user: mongo_o
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


# stop/ensure filebeat service is stopped
stop-filebeat:
    service.dead:
    - name: filebeat

# backup of old filebeat version
backup-filebeat-directory:
    cmd.run:
        - name: cp -pr /work/etc /work/etc.bak
        - onlyif: /usr/bin/ls /work/etc

# remove-old-filebeat:
#     cmd.run:
#         - name: rpm -e filebeat-7.17.3-1.x86_64
#         - require:
#             - backup-filebeat-directory
#             - stop-filebeat
#         - onlyif: rpm -q filebeat-7.17.3-1.x86_64

# installing filebeat from rpm
install-filebeat-8.2.2:
    cmd.run:
     - name: rpm -Uvh --prefix=/work/filebeat "/software/filebeat/filebeat-8.2.2-x86_64.rpm"
     - require:
        #- create-workdir-filebeat
        #- mount-software
        - stop-filebeat
     #- unless: /usr/bin/ls /work/filebeat/usr/share/filebeat/bin/filebeat
     - unless: rpm -q filebeat-8.2.2-x86_64

# move files from 7.17.3 to 8.2.2 version
move-filebeat-yml:
    cmd.run:
        - name: cp -pr /work/etc/filebeat/filebeat.yml.rpmsave /work/filebeat/etc/filebeat/filebeat.yml
        - require:
            - install-filebeat-8.2.2
        - onlyif: /usr/bin/ls /work/etc/filebeat/filebeat.yml.rpmsave


move-mongodb-yml:
    cmd.run:
        - name: cp -pr /work/etc/filebeat/modules.d/mongodb.yml /work/filebeat/etc/filebeat/modules.d/mongodb.yml
        - require:
            - install-filebeat-8.2.2
        - onlyif: /usr/bin/ls /work/etc/filebeat/modules.d/mongodb.yml


# replace the filebeat.service
# advice to check the correct user in the filebeat.service
change-filebeat-service:
    file.managed:
        - name: /etc/systemd/system/filebeat.service
        - source: salt://bruno/filebeat-upgrade/osa/filebeat.service
        - user: root
        - group: root
        - mode: 644
        - backup: .bak
        - require:
          - install-filebeat-8.2.2
    cmd.run:
        - name: systemctl daemon-reload
        - onchanges:
            - file: /etc/systemd/system/filebeat.service

# change permission on the directory
apply-permission-work:
    file.directory:
        - name: /work/filebeat
        - user: mongo_o
        - group: companyusers
        - mode: 755
        - makedirs: True
        - recurse:
            - user
            - group
            - mode
apply-permission-log:
    file.directory:
        - name: /log/filebeat
        - user: mongo_o
        - group: companyusers
        - mode: 755
        - makedirs: True
        - recurse:
            - user
            - group
            - mode
    service.running:
        - name: filebeat
        - enable: True

# replace/move the keystore that was set up in the previous version
move-filebeat-keystore:
    cmd.run:
        - name: cp -pr /work/etc/var/lib/filebeat/filebeat.keystore /work/filebeat/etc/var/lib/filebeat/
        - onlyif: /usr/bin/ls /work/etc/var/lib/filebeat/filebeat.keystore
