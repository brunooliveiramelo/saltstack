# Create the logical volumes in datavg1 as disk space standard requested 
# by the Mongo Team 
make-lvpage1:
    lvm.lv_present:
    - name: lvpage1
    - vgname: datavg1
    - size: 30G

make-lvworkdata_nplinkime_db1:
    lvm.lv_present:
    - name: lvworkdata_nplinkime_db1
    - vgname: datavg1
    - size: 1.5T
make-lvworkmongdb_binaries:
    lvm.lv_present:
    - name: lvworkmongdb_binaries
    - vgname: datavg1
    - size: 10G
make-mongodb_npl_loglv:
    lvm.lv_present:
    - name: mongodb_npl_loglv
    - vgname: datavg1
    - size: 1.5T

# Create and mount file systems
create-lvpage1:
    blockdev.formatted:
    - name: /dev/datavg1/lvpage1
    - fs_type: swap
    - require:
      - make-lvpage1

mount-lvpage1:
    mount.mounted:
    - name: swap
    - device: /dev/datavg1/lvpage1
    - fstype: swap
    - mkmnt: True
    - pass_num: 0
    - dump: 0
    - persist: True
    - opts:
        - pri=14
    - require:
        - create-lvpage1

create-lvworkdata_nplinkime_db1:
    blockdev.formatted:
    - name: /dev/datavg1/lvworkdata_nplinkime_db1
    - fs_type: xfs
    - require:
        - make-lvworkdata_nplinkime_db1

mount-lvworkdata_nplinkime_db1:
    mount.mounted:
    - name: /work/data/mongodb/nplinkime/db1
    - device: /dev/datavg1/lvworkdata_nplinkime_db1
    - fstype: xfs
    - mkmnt: True
    - pass_num: 2
    - dump: 1
    - persist: True
    - opts:
     - defaults
    - require:
      - create-lvworkdata_nplinkime_db1


create-lvworkmongdb_binaries:
    blockdev.formatted:
    - name: /dev/datavg1/lvworkmongdb_binaries
    - fs_type: xfs
    - require:
        - make-lvworkmongdb_binaries

create-mongodb_npl_loglv:
    blockdev.formatted:
    - name: /dev/datavg1/mongodb_npl_loglv
    - fs_type: xfs
    - require:
        - make-mongodb_npl_loglv

