# Set application grain to contain splunkforwarder
splunkforwarder:
  grains.present:
    - name: application
    - value: splunkforwarder

# Extend /work to 8 Gbytes
extend-work:
  cmd.run:
    - name: /sbin/lvextend -L 8G -qq -r /dev/datavg1/worklv

# Create directory structure for the splunkforwarder
work-clr:
  file.directory:
    - name: /work/clr
    - user: root
    - group: root
    - dir_mode: 755

work-clr-splunk:
  file.directory:
    - name: /work/clr/splunk
    - user: splunk_p
    - group: companyusers
    - dir_mode: 755