#!/bin/bash
version="1.0.7"
# This script unmounts the following filesystem types:
# - cifs (Common Internet File System)
# - blobfuse (Azure Blob Storage FUSE)
# - nfs (Network File System)
# - convmvfs (Converged Virtual File System) 
# - s3fs (Amazon S3 File System)
# - rclone (Rclone mount)
# It does this by:
# 1. Getting a list of all mounted filesystems of those types using `mount`
# 2. Unmounting each filesystem in that list using `umount`
# 3. Checking if the unmount was successful. If not:
#    - Getting the PID of the process using the filesystem with `fuser`
#    - Printing an error message with details
#    - Exiting with error code 1
# 4. Printing a message confirming the filesystem was unmounted
for fs in `mount | egrep "cifs|blobfuse|nfs|convmvfs|s3fs|fuse.rclone" | awk '{print  $3}'` #  Just cifs, blobfuse, nfs, convmvfs, and rclone mount points
do
echo  `date +%Y%m%d.%T` Umounting $fs
        umount $fs #    Umount mount points
         if [ $? != 0 ]; then
           pid=$(fuser $fs | awk '{print $NF}')
           echo "No se puede desmontar el FS $fs por el proceso $pid"
           ps -efa |grep $pid
           exit 1
        fi
echo  `date +%Y%m%d.%T` umounted  $fs
done