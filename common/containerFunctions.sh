# Functions.sh:
version="1.0.0 "

avamarDockerfile() {

  local dockerfile=$1
  local ConfigDir=$2
  local post_install_script_file=$3
  
# .avagent
echo "--hostname="$container_containerName > $temp_dir/.avagent
echo "--listenport="$avamar_avamarClientPort >> $temp_dir/.avagent
# avtar.cmd
echo "--run-at-start-clause=timeout-seconds=72000" > $temp_dir/avtar.cmd
# Avamar
echo 'if [ -z ${1} ]; then' >> $post_install_script_file
echo "/$ConfigDir/etc/avagent.d register $avamar_avamarServerName /$avamar_avamarDomain" >> $post_install_script_file
echo 'elif [ ${1} = "-u" ]; then' >> $post_install_script_file
echo "/etc/init.d/avagent restart" >> $post_install_script_file
echo "fi" >> $post_install_script_file
echo "# Force avamar client name through .avagent file" >> $dockerfile
echo "COPY $temp_dir/.avagent $ConfigDir/var" >> $dockerfile
echo "COPY $temp_dir/avtar.cmd $ConfigDir/var" >> $dockerfile
echo "# Avamar Client inbond ports" >> $dockerfile
echo "EXPOSE avamar_avamarClientPort" >> $dockerfile
echo "EXPOSE 30001" >> $dockerfile
echo "EXPOSE 30002" >> $dockerfile
echo "# Avamar Client outbond ports" >> $dockerfile
echo "EXPOSE 53" >> $dockerfile
echo "EXPOSE 123" >> $dockerfile
echo "EXPOSE 443" >> $dockerfile
echo "EXPOSE 3008" >> $dockerfile
echo "EXPOSE 8105" >> $dockerfile
echo "EXPOSE 8109" >> $dockerfile
echo "EXPOSE 8181" >> $dockerfile
echo "EXPOSE 8444" >> $dockerfile
echo "EXPOSE 27000" >> $dockerfile
echo "EXPOSE 27001" >> $dockerfile
echo "EXPOSE 29000" >> $dockerfile
echo "EXPOSE 30101" >> $dockerfile
echo "EXPOSE 30102" >> $dockerfile
  
echo "COPY $post_install_script_file $ConfigDir" >> $dockerfile

cat > $BackupPaaS_script_file << EOF
#!/bin/bash
# Version 1.0.3
systemctl restart avagent 
mount -a
EOF

cat > $systemctl_BackupPaaS_script_file << EOF
# Script.service
[Unit]
Description=Restarts Avamar agent. Mounts target storage units
After=network.target

[Service]
Type=oneshot
ExecStart=$BackupPaaS_script_file
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
}

powerProtectMount() {

  local post_install_script_file=$1
                                  
# Ddboostfs & Lockbox
echo DDBOOST_USER=$datadomain_ddboosfs_ddboostuser >> $post_install_script_file
echo DD_SERVER=$datadomain_datadomainServerName >> $post_install_script_file
echo STORAGE_UNIT=$datadomain_ddboosfs_storageUnit >> $post_install_script_file
echo LOCKBOXPASS=$datadomain_ddboosfs_lockboxPass >> $post_install_script_file
echo '/usr/bin/expect <<-EOF
spawn /opt/emc/boostfs/bin/boostfs lockbox set -u $DDBOOST_USER -d $DD_SERVER -s $STORAGE_
expect "Enter storage unit user password:"
send "$LOCKBOXPASS\r"
expect "Enter storage unit user password again to confirm:"
send "$LOCKBOXPASS\r""
expect "Lockbox entry set"
EOF
' >> $post_install_script_file
echo "echo '$datadomain_datadomainServerName:/$datadomain_ddboosfs_storageUnit /$datadomain_datadomain_datadomain_datadomain_RootBackupDir boostfs defaults,_netdev,bfsopt(nodsp.small_file_check=0,app-info="DDBoostFS") 0 0' >> /etc/fstab" >> $post_install_script_file
echo "mount -a" >> $post_install_script_file
}