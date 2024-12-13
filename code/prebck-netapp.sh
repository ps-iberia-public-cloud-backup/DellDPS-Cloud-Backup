#!/bin/bash
# This script mounts a NetApp Files as filesystem.
version="2.2.4"
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

#
ERROR=1
[ ! -d $LogDir ] && mkdir $LogDir
exec &>> >(tee -a $LogFile)

echo
echo !!!!! Processing config file !!!!!
echo
if [ -f ${ConfigDir}/resources ]; then rm -rf ${ConfigDir}/resources; fi
echo
echo "*********************************** SEARCHING cloud resources **************************************"
echo

echo "Autodiscover value is: $azureResources_useAutoDiscover"

if [ $azureResources_useAutoDiscover == "YES" ] || [ $azureResources_useAutoDiscover == "yes"  ]; then

ACCOUNTS=(`az netappfiles account list --resource-group $avamar_azureDeploy_resourceGroup | jq -r .[].name`)
if [ -z  ${ACCOUNTS}   ]; then echo "ERROR: No netapp accounts found. EXIT "; exit ; fi
    for ACCOUNT in ${ACCOUNTS[@]}; do
      POOLS=(`az netappfiles pool list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} | jq -r .[].name `)
      if [ -z  ${POOLS}   ]; then echo "ERROR: No pools found withing this netapp account ${ACCOUNT} . skipping this account "; continue ; fi
          for POOL in ${POOLS[@]}; do
              POOL=${POOL##*/}
              SHARES=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} | jq -r .[].creationToken `)
              if [ -z  ${SHARES}   ]; then echo "ERROR: No volumes found withing this pool ${POOL} . skipping this volume "; continue ; fi
              for SHARE in ${SHARES[@]}; do
                  echo !!!!! Mounting volume ${SHARE} of the pool ${POOL} of the storage account ${ACCOUNT} !!!!!

                  if [ ! -d ${ServiceBackupDir}/${SHARE} ]; then mkdir -p ${ServiceBackupDir}/${SHARE}; fi
                  if [ ! -d ${ServiceBackupDir}/restore ]; then mkdir -p ${ServiceBackupDir}/restore; fi

                  mntPath=${ServiceBackupDir}/${SHARE}
                  SHAREVERSION3=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} --query "[?creationToken=='$SHARE']" | jq -r .[]."exportPolicy".rules[]."nfsv3"`)
                  SHAREVERSION4=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} --query "[?creationToken=='$SHARE']" | jq -r .[]."exportPolicy".rules[]."nfsv41"`)
                  SHAREIP=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} --query "[?creationToken=='${SHARE}']" | jq -r .[]."mountTargets"[]."ipAddress"`)

                  if (${SHAREVERSION3} -eq true ); then
                        mount -t nfs -o ro,nolock,hard,rsize=65536,wsize=65536,vers=3,tcp ${SHAREIP}:/${SHARE} /${mntPath}
                  elif (${SHAREVERSION4} -eq true ); then
                        mount -t nfs -o ro,nolock,hard,rsize=65536,wsize=65536,sec=sys,vers=4.1,tcp ${SHAREIP}:/${SHARE} /${mntPath}
                  fi
                  if [ $? != "0" ] || [ $? != "1" ]; then
                        echo "************************* `date +%Y%m%d.%T` ERROR 010: Unable to Mount ${SHARE} skipping this , EXIT *************************"
                        break
                  fi
              done
          done
    done
elif [ $azureResources_useAutoDiscover == "NO" ] || [ $azureResources_useAutoDiscover == "no"  ] ; then
  VOLUMES=($(echo $RESOURCELIST_FIX | tr ',' '\n'))
  for VOLUME in ${VOLUMES[@]}; do
      VOLUME=($(echo $VOLUME | tr '/' '\n'))
      ACCOUNT=${VOLUME[0]}
      POOL=${VOLUME[1]}
      SHARE=${VOLUME[2]}
      if [ "${SHARE}" = "ALL" ]; then
          SHARES=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} | jq -r .[].creationToken `)
          if [ -z  ${SHARES}   ]; then echo "ERROR: No volumes found withing this pool ${POOL} . skipping this volume "; continue ; fi
          for SHARE in ${SHARES[@]}; do
              echo !!!!! Mounting volume ${SHARE} of the pool ${POOL} of the storage account ${ACCOUNT} !!!!!
              if [ ! -d ${ServiceBackupDir}/${SHARE} ]; then mkdir -p ${ServiceBackupDir}/${SHARE}; fi
              if [ ! -d ${ServiceBackupDir}/restore ]; then mkdir -p ${ServiceBackupDir}/restore; fi
              mntPath=${ServiceBackupDir}/${SHARE}
              SHAREVERSION3=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} --query "[?creationToken=='$SHARE']" | jq -r .[]."exportPolicy".rules[]."nfsv3"`)
              SHAREVERSION4=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} --query "[?creationToken=='$SHARE']" | jq -r .[]."exportPolicy".rules[]."nfsv41"`)
              SHAREIP=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} --query "[?creationToken=='${SHARE}']" | jq -r .[]."mountTargets"[]."ipAddress"`)
              if (${SHAREVERSION3} -eq true ); then
                    mount -t nfs -o ro,nolock,hard,rsize=65536,wsize=65536,vers=3,tcp ${SHAREIP}:/${SHARE} /${mntPath}
              elif (${SHAREVERSION4} -eq true ); then
                    mount -t nfs -o ro,nolock,hard,rsize=65536,wsize=65536,sec=sys,vers=4.1,tcp ${SHAREIP}:/${SHARE} /${mntPath}
              fi
              if [ $? != "0" ] || [ $? != "1" ]; then
                  echo "************************* `date +%Y%m%d.%T` ERROR 010: Unable to Mount ${SHARE} skipping this , EXIT *************************"
                  break
              fi
          done
      else
          echo !!!!! Mounting volume ${SHARE} of the pool ${POOL} of the storage account ${ACCOUNT} !!!!!
          if [ ! -d ${ServiceBackupDir}/${SHARE} ]; then mkdir -p ${ServiceBackupDir}/${SHARE}; fi
          if [ ! -d ${ServiceBackupDir}/restore ]; then mkdir -p ${ServiceBackupDir}/restore; fi

          mntPath=${ServiceBackupDir}/${SHARE}
          SHAREVERSION3=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} --query "[?creationToken=='$SHARE']" | jq -r .[]."exportPolicy".rules[]."nfsv3"`)
          if [ -d ${SHAREVERSION3} ]; then
              echo "************************* `date +%Y%m%d.%T` ERROR 011: please verify the Account name, Pool Name, Volume Name , EXIT *************************"
              break
          fi
          SHAREVERSION4=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} --query "[?creationToken=='$SHARE']" | jq -r .[]."exportPolicy".rules[]."nfsv41"`)
          SHAREIP=(`az netappfiles volume list --resource-group $avamar_azureDeploy_resourceGroup --account-name ${ACCOUNT} --pool-name ${POOL} --query "[?creationToken=='${SHARE}']" | jq -r .[]."mountTargets"[]."ipAddress"`)

          if (${SHAREVERSION3} -eq true ); then
                mount -t nfs -o ro,nolock,hard,rsize=65536,wsize=65536,vers=3,tcp ${SHAREIP}:/${SHARE} /${mntPath}
          elif (${SHAREVERSION4} -eq true ); then
                mount -t nfs -o ro,nolock,hard,rsize=65536,wsize=65536,sec=sys,vers=4.1,tcp ${SHAREIP}:/${SHARE} /${mntPath}
          fi
          if [ $? != "0" ] || [ $? != "1" ]; then
                echo "************************* `date +%Y%m%d.%T` ERROR 010: Unable to Mount ${SHARE} skipping this , EXIT *************************"
                break
          fi
      fi
  done
else
    echo "************************* Please specify whether to use azureResources_useAutoDiscovery or not in the dps-setup.json file. EXIT *************************"
    exit
fi

# Azure logout
az_logout $version $containerType