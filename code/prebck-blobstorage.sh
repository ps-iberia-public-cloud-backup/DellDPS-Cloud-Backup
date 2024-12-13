#!/bin/bash
# This script mounts a blobfuse as filesystem.
version="1.0.1"

ConfigDir=$(head -1 /tmp/seed.txt)
ScriptDir=$(sed -n '2p' /tmp/seed.txt)

source $ScriptDir/common/functions.sh    # bash functions
source $ScriptDir/common/azureFunctions.sh    # bash functions

## + Json parsing
    input_json="${ConfigDir}/dps-setup.json"  # Input JSON file path.
    output_file="output.json"  # Output JSON file path.

    # Call the json_parsing function with the specified input and output files.
    json_parsing "$input_json" "$output_file"
## - End Json parsing

az_login
header $version $containerType
folders

# Log file path
log_file="$LogDir/$scriptName.log"
log_message "Backup started" $log_file

delete_file ${ConfigDir}/resources
current_time=$(get_current_datetime)

if [ ${azureResources_useAutoDiscover} = "YES" ]; then

    echo "$current_time: SEARCHING All cloud resources"
    STA=($(az storage account list --query "[].{name:name}" --output tsv))
    for i in ${STA[@]}; do az_get_storage_account_private_endpoint $i; done

else
    
    echo "$current_time: LISTING cloud resources"
    storage_account_name=$(echo ${fixTags_resource_list} | tr "," "\n")
    az_get_storage_account_private_endpoint $storage_account_name

fi

az_tags 

check_file_exists ${ConfigDir}/resources

cat ${ConfigDir}/resources | while read linea
do
    set -a $linea " "
    if [ "${1::1}" != "#" ] ; then
        
        storage_account_name=$linea
 
        if [ $blobstorage_useBlobFuse == "YES" ]; then

            if [ $blobstorage_blobfuse_useKeys == "YES" ]; then
                blobaccessmethod="keys"
            elif [ $blobstorage_blobfuse_RBACAccess_useServicePrincipal == "YES" ]; then
                blobaccessmethod="servicePrincipal"
            elif [ $blobstorage_blobfuse_RBACAccess_useManagerServiceIdentity == "YES" ]; then
                echo "Not yet implemented"
            else    
                echo "Please configure keys based access method or RBAC based access method"; exit 1                        
            fi           

            if [ "$blobstorage_blobfuse_version" = "2" ] && [ "$blobstorage_blobfuse_mountAll" = "YES" ]; then mountblobfuse2all $storage_account_name --read-only $blobaccessmethod # Blobfuse2 mount all
            elif [ "$blobstorage_blobfuse_version" = "2" ] && [ "$blobstorage_blobfuse_mountAll" = "NO" ]; then mountblobfuse2 $$storage_account_name --read-only $blobaccessmethod  # Blobfuse2 mount by container
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
