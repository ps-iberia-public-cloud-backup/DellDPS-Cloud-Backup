#!/bin/bash
# Avamar script for restore secrets, certificates and/or keus to a Azure Key Vault.
# Objects must be downloaded to a filesystem before running this script.
version="1.0.12"
set -euo pipefail

scriptName=`basename "$0"`
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
az_tags
folders

AKVRESTORE=$1

echo
echo !!!!! Processing config file !!!!!
echo
for i in `ls $RestoreDir/*.S.*`
do
                echo "***************************** Restore of secret $i in KeyVault $AKVRESTORE *********************************"
                az keyvault secret restore --file $i --vault-name $AKVRESTORE
done

for i in `ls $RestoreDir/*.C.*`
do
                echo "***************************** Restore of certicate $i in KeyVault $AKVRESTORE *********************************"
                az keyvault certificate restore --file $i --vault-name $AKVRESTORE
done 

for i in `ls $RestoreDir/*.K.*`
do
                echo "***************************** Restore of key $i in KeyVault $AKVRESTORE *********************************"
                az keyvault key restore --file $i --vault-name $AKVRESTORE
done

# Azure logout
az_logout $version $containerType