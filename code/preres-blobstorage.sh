#!/bin/bash
# This script mounts a blobfuse as filesystem as read-write.
version="1.0.0"

ConfigDir=`cat /tmp/ConfigDir.txt`

if [ $(rpm -qa|grep -i avamar) ]; then
    ScriptDir=$ConfigDir/etc/scripts
else
    ScriptDir=$ConfigDir
fi

source $ScriptDir/common/functions.sh    # bash functions
source $ScriptDir/common/azureFunctions.sh    # azure functions
$ScriptDir/common/jsonParser.sh $ConfigDir/dps-setup.json # environment variables from json file

az_login
header
delete_file ${ConfigDir}/resources
current_time=$(get_current_datetime)

if [ ${AUTODISCOVER} = "YES" ]; then

    echo "$current_time: SEARCHING All cloud resources"
    STA=($(az storage account list --query "[].{name:name}" --output tsv))
    for i in ${STA[@]}; do az_get_storage_account_private_endpoint $i; done

else
    
    echo "$current_time: LISTING cloud resources"
    storage_account_name=$(echo ${RESOURCELIST_FIX} | tr "," "\n")
    az_get_storage_account_private_endpoint $storage_account_name

fi

az_tags $RESOURCES

check_file_exists ${ConfigDir}/resources

cat ${ConfigDir}/resources | while read linea
do
    set -a $linea " "
    if [ "${1::1}" != "#" ] ; then

            storage_account_name="$1"
            az_get_storage_account_keys $storage_account_name

            if [ $blobstorage_useBlobFuse == "YES" ]; then

                if [ "$blobstorage_blobfuse_version" = "2" ] && [ "$blobstorage_blobfuse_mountAll" = "YES" ]; then mountblobfuse2all $storage_account_name   # Blobfuse2 mount all
                elif [ "$blobstorage_blobfuse_version" = "2" ] && [ "$blobstorage_blobfuse_mountAll" = "NO" ]; then mountblobfuse2 $$storage_account_name    # Blobfuse2 mount by container
                else echo Blobfuse version not supported; fi                                                                                 
                        
            elif [ $blobstorage_useRclone == "YES" ]; then
            
                if [ ! -d /root/.config/rclone ]; then mkdir -p /root/.config/rclone; fi
                RCLONE_CONFIG=/root/.config/rclone/rclone.conf
                echo "
                [$storage_account_name]
                type = azureblob
                account = $storage_account_name
                key = ${key}
                " >> $RCLONE_CONFIG
                mountrcloneforblobfuse $storage_account_name
                delete_file $RCLONE_CONFIG

            else

                echo "$current_time: Please specify blobfuse or rclone mount method"

            fi

    fi
done

footer

delete_file ${ConfigDir}/resources

exit 0

