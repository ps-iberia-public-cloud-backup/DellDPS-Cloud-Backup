#!/bin/bash
# Avamar script for backup in Azure PostgreSQL.
version="1.0.12"
set -euo pipefail
scriptName=`basename "$0"`

ConfigDir=$(head -1 /tmp/seed.txt)
ScriptDir=$(sed -n '2p' /tmp/seed.txt)

# Log file path
log_file="$scriptName.log"

log_message "Backup started"

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
#az_tags
folders

echo
echo !!!!! Processing config file !!!!!
echo
if [ -f ${ConfigDir}/keyvault.list ]; then rm -rf ${ConfigDir}/keyvault.list; fi
if [ -f ${ConfigDir}/akvnotprivep ]; then rm -rf ${ConfigDir}/akvnotprivep; fi

json_file=${ConfigDir}/dps-setup.json


#checkAvtarInclude   # Validates that the directory named in --include of ${ConfigDir}/var/avtar.cmd actually exists.

export NO_PROXY=.vault.azure.net

if [ $azureResources_useAutoDiscover = "YES" ]; then
    echo
    echo "*********************************** SEARCHING cloud resources **************************************"
    echo
    keyvaults=$(az keyvault list --resource-group $avamar_azureDeploy_resourceGroup -o table | tail -n +3 | awk {'print $2'}) > ${ConfigDir}/keyvault.list
else
    echo "*********************************** LISTING cloud resources **************************************"
    echo
    echo $RESOURCELIST_FIX | tr "," "\n" > ${ConfigDir}/keyvault.list
fi

vaultsExcluded=$(cat "$json_file" | jq -r '.keyvault.secrets.exclude | to_entries[] | "\(.key): \(.value)"' | grep -v _secrets |awk '{print $2}'|  tr '\n' ' ')

cat ${ConfigDir}/keyvault.list | while read keyvault
do
    PeP=$(az keyvault show -n $keyvault --query properties.privateEndpointConnections[].privateEndpoint.id)
    if [ ! -z "$PeP" ]; then

    set +e
    errorsecret=$(az keyvault secret list --vault-name $keyvault -o json 2>&1)
    errorcertif=$(az keyvault certificate list --vault-name $keyvault -o json 2>&1)
    errorkey=$(az keyvault key list --vault-name $keyvault -o json 2>&1)

    if [ $(echo $errorsecret |awk '{print $1}') = "ERROR:" ] || [ $(echo $errorcertif |awk '{print $1}') = "ERROR:" ] || [ $(echo $errorkey |awk '{print $1}') = "ERROR:" ]; then echo "There is an error with AKV $keyvault"; exit 1;
    else
      secretlist=$(echo $errorsecret |jq -r .[].name)
      certlist=$(echo $errorcertif |jq -r .[].name)
      keylist=$(echo $errorkey |jq -r .[].name)
    fi
    set -e

    if [ -z "$secretlist" ]; then
      echo "The AKV $keyvault does not have secrets";
      else

            for secret in ${secretlist[@]}
            do
                excludeSecret=$(check_vault_and_secret "$json_file" "$keyvault" "$vaultsExcluded" "$secret")
                if [ $excludeSecret = "doNotBackup" ]; then
                    echo "***************************** The secret $secret of Key Vault $keyvault will be bypassed by json config*********************************"
                else
                    echo "***************************** Backup of secret $secret of Key Vault $keyvault *********************************"
                    az keyvault secret backup --file ${BackupDirByCont}/$container_containerName.$keyvault.$secret.S.$(date +%Y%m%d%H%M%S).bkp --vault-name $keyvault --name $secret
                fi
            done

    fi

    if [ -z "$certlist" ]; then echo "The AKV $keyvault does not have certificates";
      else
          for j in ${certlist[@]}
          do
              echo "***************************** Backup of certificate $j of Key Vault $keyvault *********************************"
              az keyvault certificate backup --file ${BackupDirByCont}/$container_containerName.$keyvault.$j.C.$(date +%Y%m%d%H%M%S).bkp --vault-name $keyvault --name $j
          done
    fi

    if [ $keyvault_backupKeys = "YES" ]; then

        if [ -z "$keylist" ]; then echo "The AKV $keyvault does not have keys";
        else
            for j in ${keylist[@]}
            do
                echo "***************************** Backup of key $j of Key Vault $keyvault *********************************"
                az keyvault key backup --file ${BackupDirByCont}/$container_containerName.$keyvault.$j.K.$(date +%Y%m%d%H%M%S).bkp --vault-name $keyvault --name $j
            done
        fi

    fi

    else
      echo "The Key Vault $keyvault does not have Private end Point and cannot make backup"; exit
    fi
done

delete_file ${ConfigDir}/keyvault.list
# Azure logout
az_logout $version $containerType
log_message "Backup finished"
