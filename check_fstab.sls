add_script_check_fstab:
    file.managed:
    - name: /local/bin/chk_fstab.sh
    - source: salt://checks/scripts/chk_fstab.sh
    - mode: 0700

run_script_check_fstab:
    cmd.run:
    - name: /local/bin/chk_fstab.sh
    file.absent:
    - name: /local/bin/chk_fstab.sh