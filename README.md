For crontab:

@reboot /bin/bash -c "/bin/bash /root/ifcon.sh read_syslog >/dev/null 2>&1"

0 */3 * * * /bin/bash -c "/bin/bash /root/ifcon_complex.sh scan_ccd_directory"
