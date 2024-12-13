#!/bin/bash
version="1.0.14"
# This is an archiving script to be run after the backup is finished.
set -euo pipefail
scriptName=`basename "$0"`

removeLock() {
  if [ -f ${1} ]; then rm -rf ${1}; fi
}

trap "removeLock" SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM

# Checks if the backup directory is mounted as blobfuse. If not, proceeds to mount it.
fstype=`df ${BackupDir} | tail -n+2 | awk {'print $1'}`
if [ $fstype != blobfuse ]; then 
        # If the backup directory is not a blobfuse or overlay then we need to mount it
        echo "*** DDboost FS cleaning with script ${scriptName} ***"
        # Deletes log files older than 15 days
        logfiles=$(shopt -s nullglob dotglob; echo ${LogDir}/${SERVICE_TYPE}*)
        if (( ${#logfiles} )); then find ${LogDir}/${SERVICE_TYPE}* -mtime +15 -type f -exec rm {} \;; fi
        # If azureResources_useAutoDiscover is set to YES, moves old backup folders to the OldBackupDir
        if [ $azureResources_useAutoDiscover = "YES" ]; then
                contents=$(shopt -s nullglob dotglob; echo ${BackupDir}/*)
if (( ${#contents} )); then 
    if [ -f ${RestoreDir}/remove.lock ]; then 
        echo "There are a ${RestoreDir}/remove.lock file. Nothing to do on ${BackupDir}" 
    else 
        touch ${RestoreDir}/remove.lock 
        echo Housekeeping with azureResources_useAutoDiscover 
        for folder in $contents; do 
            RemoveDir=${OldBackupDir}/$(echo $folder | rev | cut -d'/' -f 1 | rev) 
            if [ -d  ${RemoveDir} ]; then rm -rf ${RemoveDir}; fi 
        done 
        echo $contents | xargs mv -t ${OldBackupDir} -- 
        removeLock ${RestoreDir}/remove.lock 
    fi 
fi
        # If azureResources_useAutoDiscover is set to NO, moves old backup folders for the specified container_containerName to the OldBackupDir
        elif [ $azureResources_useAutoDiscover = "NO" ]; then
                contents=$(shopt -s nullglob dotglob; echo ${BackupDir}/*$container_containerName*)
                if (( ${#contents} )); then
                        if [ -f ${RestoreDir}/remove.$container_containerName.lock ]; then
                                echo "There are a ${RestoreDir}/remove.$container_containerName.lock file. Nothing to do on ${BackupDir}/*$container_containerName*"
                        else
                                touch ${RestoreDir}/remove.$container_containerName.lock
                                echo Housekeeping without azureResources_useAutoDiscover
                                for folder in $contents; do
                                        RemoveDir=${OldBackupDir}/$(echo $folder | rev | cut -d'/' -f 1 | rev)
                                        if [ -d  ${RemoveDir} ]; then rm -rf ${RemoveDir}; fi
                                done
                                echo $contents | xargs mv -t ${OldBackupDir} --
                                removeLock ${RestoreDir}/remove.$container_containerName.lock
                        fi
                fi
        fi
# Deletes backup folders in OldBackupDir older than 3 days       
        oldfiles=$(shopt -s nullglob dotglob; echo ${OldBackupDir}/*$container_containerName*)
        if (( ${#oldfiles} )); then
                if [ -f ${RestoreDir}/remove.$container_containerName.lock ]; then
                        echo "There are a ${RestoreDir}/remove.$container_containerName.lock file. Nothing to do on ${OldBackupDir}"
                else
                        touch ${RestoreDir}/remove.$container_containerName.lock
                        echo Deleting old data
                        find ${oldfiles} -mtime +3 > delete.$container_containerName.txt
                        cat delete.$container_containerName.txt | while read linea
                        do
                          rm -rf $linea
                        done
                        removeLock ${RestoreDir}/remove.$container_containerName.lock
                fi
        fi
fi