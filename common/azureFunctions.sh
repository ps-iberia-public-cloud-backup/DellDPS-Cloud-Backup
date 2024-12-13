# Azure functions.sh:
version="1.0.1"
scriptName=`basename "$0"`
### 
azchangeDefaultsubscription() {

    if [ $azureLogin_subscription_changeDefaultsubscription = "YES" ]; then az account set --subscription $azureLogin_subscription_subscriptionID; fi

}

az_login() {    

set +euo pipefail
CurrentTenant=$(az account show | jq -r '.tenantId')
set -euo pipefail

if [ -z ${CurrentTenant} ]; then CurrentTenant="NoLogged"; fi

if [ -z $azureLogin_tenantId ]; then echo "azureLogin_tenantId is not set"; exit 1; fi

if [ ${CurrentTenant} = ${azureLogin_tenantId} ]; then echo You are logged
else
    if [ $azureLogin_ServicePrincipal_useServicePrincipal = "YES" ]; then
        if [ ! -z $azureLogin_ServicePrincipal_servicePrincipalClientId ]; then                
                if [ -z $azureLogin_ServicePrincipal_KeyVaultno_servicePrincipalClientSecret ]; then
                        echo "Getting Azure token"
                        token=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -H Metadata:true | sed -n 's|.*"access_token": *"\([^"]*\)".*|\1|p')
                        if [ -z "${token}" ]; then echo "Error - No token in KeyVault"; exit 1; fi
                        if [ ${token:2:5} == "error" ]; then echo "Error getting token from keyVaultName"; exit 1; fi
                        echo  "Using Service Principal and Key Vault Secret"
                        response=$(curl https://$azureLogin_ServicePrincipal_keyVaultNameyes_loginkeyVaultNameName.vault.azure.net/secrets/$azureLogin_ServicePrincipal_KeyVaultno_servicePrincipalClientSecret?api-version=2016-10-01 -H "Authorization: Bearer ${token}")
                        if [ ${response:2:5} == "error" ]; then echo "Error getting key from from keyVaultName"; exit 1; fi
                        azureLogin_ServicePrincipal_KeyVaultno_servicePrincipalClientSecret=$(echo $response | python3 -c 'import sys, json; print (json.load(sys.stdin)["value"])')
                        az login --service-principal --username $azureLogin_ServicePrincipal_servicePrincipalClientId --password  $azureLogin_ServicePrincipal_KeyVaultno_servicePrincipalClientSecret --tenant $azureLogin_tenantId &> /dev/null
                        if [ $? -eq 0 ]; then echo "Logged in * SP and KVS"; azchangeDefaultsubscription; else echo "Service Principal with Key Vault Login using Secret failed, review json file config"; exit 1; fi
                else
                        echo "Using Service Principal without Key Vault"
                        az login --service-principal --username $azureLogin_ServicePrincipal_servicePrincipalClientId --password $azureLogin_ServicePrincipal_KeyVaultno_servicePrincipalClientSecret --tenant $azureLogin_tenantId &> /dev/null
                        if [ $? -eq 0 ]; then echo "Logged in * SP"; azchangeDefaultsubscription;  else echo "Service Principal without Key Vault Login failed, review json file config"; exit 1; fi
                fi
        else
                echo "Service Principal Client ID is not set"; exit 1;
        fi
    fi
    if [ $azureLogin_ManagedIdentity_useUserAssignedRManagedIdentity = "YES" ]; then
        echo    "User Assigned Manage Identity Login"
        az login --identity --username /subscriptions/$azureLogin_subscription_subscriptionID/azureLogin_resourceGroups/$azureLogin_resourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$MANAGEDIDENTITYNAME &> /dev/null
        if [ $? -eq 0 ]; then echo "Logged in * UAMI"; azchangeDefaultsubscription; fi
    else
        if [ $azureLogin_ManagedIdentity_useSystemAssignedManagedIdentity = "YES" ]; then
                echo    "System Assigned Manage Identity Login"
                az login --identity &> /dev/null
                if [ $? -eq 0 ]; then echo "Logged in * SAMI"; azchangeDefaultsubscription; fi
        fi
    fi
    if [ $azureLogin_Credentials_useCredentials = "YES" ]; then
        echo    "User Credential Login"
        az login --username $azureLogin_Credentials_useCredentialsUSERNAME --password $azureLogin_Credentials_useCredentialsPASSWORD &> /dev/null
        if [ $? -eq 0 ]; then echo "Logged in * US"; azchangeDefaultsubscription; fi

    fi
fi
}

az_logout() {

  local version=$1
  local containerType=$2
  echo -e "\n"
  echo "*****************************************************************************************************"
  echo !!!!! `date +%Y%m%d.%T` ending and az logout job ver ${version}, service $containerType  !!!!!
  echo "*****************************************************************************************************"
  echo -e "\n"
# Logout
az logout
}

# Function to execute az commands with error handling
az_command() {
  local cmd="$1"
  echo "Executing: $cmd"
  
  # Execute the command
  eval "$cmd"
  
  # Check the exit status of the command
  if [ $? -ne 0 ]; then
    echo_and_log_message "Error: Command failed - $cmd" message.log
    exit 1
  fi
}

az_get_storage_account_private_endpoint() {
  local storage_account_name="$1"
  current_time=$(get_current_datetime)
  
  privep=$(az storage account show --name $storage_account_name --query privateEndpointConnections | jq -r '.[].name')
  
  if [ ! -z "${privep}" ]; then
    echo $storage_account_name >> ${ConfigDir}/resources
    echo "$current_time: The STA $storage_account_name has a private endpoint, can make backup"
  else
    echo "$current_time: The STA $storage_account_name has not a private endpoint, cannot make backup"
  fi
}

# Function to get the key of a storage account
az_get_storage_account_keys() {
  local storage_account_name="$1"

  # Get the key for the storage account
  key=$(az storage account keys list --account-name $storage_account_name --query "[].{value:value}" --output tsv | head -1)

  # Check if the pass is empty
  if [ -z "${key}" ]; then echo "No key for storage account $storage_account_name, exiting"; exit 1; fi
}

mountblobfuse2() {

    echo "** MOUNTING Azure Blob with BLOBFUSE2 **"
    local storage_account_name=$1
    local containers=$(az storage container list --account-name ${storage_account_name} --account-key {$key} --query "[].{name:name}" --output tsv)
    #if [ -z ${containers} ]; then echo "ERROR: No containers to backup. Review logs for details. EXIT "; exit 1; fi

    createblobfuse2TemplateFile
    
    for container in ${containers[@]}; do
        #preparing config files
        cp ${ConfigDir}/blobfuse2-template.yaml ${ConfigDir}/${container}.yaml
        replaceAccountKey "${ConfigDir}/${container}.yaml" "ACCOUNTNAME" "${storage_account_name}"
        echo "  container: ${container}" >> ${ConfigDir}/${container}.yaml
        echo "  account-key: ${key}" >> ${ConfigDir}/${container}.yaml
        echo "stream:" >> ${ConfigDir}/${container}.yaml
        echo "  block-size-mb: 8" >> ${ConfigDir}/${container}.yaml
        echo "  max-buffers: 64" >> ${ConfigDir}/${container}.yaml
        echo "  buffer-size-mb: 36" >> ${ConfigDir}/${container}.yaml
        #end of preparing config files

        if [ ! -d ${BackupDir}/$storage_account_name/${container} ];then mkdir -p ${BackupDir}/$storage_account_name/${container}; fi
        echo "$current_time: Mounting container $container of storage account $1"
        timeout 60s blobfuse2 mount ${BackupDir}/$storage_account_name/${container} --config-file=${ConfigDir}/${container}.yaml --log-level=LOG_DEBUG --file-cache-timeout-in-seconds=120 ${2} --log-file-path --secure-config /tmp/blobfuse2.$storage_account_name.${container}.log
    done

}

mountblobfuse2all() {
    echo "** MOUNTING Azure Blob with BLOBFUSE2 through mount all **"

    local storageAccount=$1
    local workload=$2 # Read only or read write
    local blobaccessmethod=$3

    createblobfuse2TemplateFile

    #preparing config files
    cp ${ConfigDir}/blobfuse2-template.yaml ${ConfigDir}/${storageAccount}.yaml
    replaceAccountKey ${ConfigDir}/${storage_account_name}.yaml "ACCOUNTNAME" "${1}"
    if [ -n "$cloudConnection_proxy_proxyHttpName" ]; then replaceAccountKey ${ConfigDir}/${storageAccount}.yaml "HTTP_PROXY" "${cloudConnection_proxy_proxyHttpName#*//}"; fi
    if [ -n "$cloudConnection_proxy_proxyHttpsName" ]; then replaceAccountKey ${ConfigDir}/${storageAccount}.yaml "HTTPS_PROXY" "${cloudConnection_proxy_proxyHttpsName#*//}"; fi
    replaceAccountKey ${ConfigDir}/${storage_account_name}.yaml "ENDPOINT" "$storageAccount"

    if [ $blobaccessmethod == "keys" ]; then

        az_get_storage_account_keys $storage_account_name
        echo "  mode: key" >> ${ConfigDir}/$storageAccount.yaml
        echo "  account-key: ${key}" >> ${ConfigDir}/$storageAccount.yaml

    elif [ $blobaccessmethod == "servicePrincipal" ]; then

        echo "  mode: spn" >> ${ConfigDir}/$storageAccount.yaml
        echo "  tenantid: TENANTID" >> ${ConfigDir}/$storageAccount.yaml
        echo "  clientid: CLIENTID" >> ${ConfigDir}/$storageAccount.yaml
        echo "  clientsecret: CLIENTSECRET" >> ${ConfigDir}/$storageAccount.yaml
        replaceAccountKey ${ConfigDir}/$storageAccount.yaml "TENANTID" "$azureLogin_tenantId"
        replaceAccountKey ${ConfigDir}/$storageAccount.yaml "CLIENTID" "$azureLogin_ServicePrincipal_servicePrincipalClientId"
        replaceAccountKey ${ConfigDir}/$storageAccount.yaml "CLIENTSECRET" "$azureLogin_ServicePrincipal_KeyVaultno_servicePrincipalClientSecret"

    else
        echo "Not yet implemented";exit 1
    fi

    # Extract and assign values to variables
    block_size_mb=$(echo $blobstorage_blobfuse_blockCacheTunning | grep -oP '(?<=block-size-mb:)\d+')
    mem_size_mb=$(echo $blobstorage_blobfuse_blockCacheTunning | grep -oP '(?<=mem-size-mb:)\d+')
    disk_size_mb=$(echo $blobstorage_blobfuse_blockCacheTunning | grep -oP '(?<=disk-size-mb:)\d+')
    disk_timeout_sec=$(echo $blobstorage_blobfuse_blockCacheTunning | grep -oP '(?<=disk-timeout-sec:)\d+')
    prefetch=$(echo $blobstorage_blobfuse_blockCacheTunning | grep -oP '(?<=prefetch:)\d+')
    parallelism=$(echo $blobstorage_blobfuse_blockCacheTunning | grep -oP '(?<=parallelism:)\d+')

    echo "block_cache::" >> ${ConfigDir}/$storageAccount.yaml
    echo "  block-size-mb: $block_size_mb" >> ${ConfigDir}/$storageAccount.yaml
    echo "  mem-size-mb: $mem_size_mb" >> ${ConfigDir}/$storageAccount.yaml
    echo "  path: /tmp" >> ${ConfigDir}/$storageAccount.yaml
    echo "  disk-size-mb: $disk_size_mb" >> ${ConfigDir}/$storageAccount.yaml
    echo "  disk-timeout-sec: $disk_timeout_sec" >> ${ConfigDir}/$storageAccount.yaml
    echo "  prefetch: $prefetch" >> ${ConfigDir}/$storageAccount.yaml
    echo "  parallelism: $parallelism" >> ${ConfigDir}/$storageAccount.yaml

    #end of preparing config files

    if [ ! -d ${BackupDir}/$storageAccount ];then mkdir -p ${BackupDir}/$storageAccount; fi
    echo  "`date +%Y%m%d.%T` Mounting all container of storage account $storageAccount"
    unset HTTP_PROXY; unset HTTPS_PROXY; unset http_proxy; unset https_proxy; unset NO_PROXY
    blobfuse2 mount all ${BackupDir}/$storageAccount --config-file=${ConfigDir}/$storageAccount.yaml $workload
    delete_file ${ConfigDir}/$storageAccount.yaml
}

createblobfuse2TemplateFile(){
    cat > ${ConfigDir}/blobfuse2-template.yaml << EOF
allow-other: false
logging:
  endpoint: https://ENDPOINT.blob.core.windows.net
  http_proxy: HTTP_PROXY
  https_proxy: HTTPS_PROXY
  type: syslog
  level: log_off
components:
  - libfuse
  - block_cache
  - attr_cache
  - azstorage
libfuse:
  attribute-expiration-sec: 120
  entry-expiration-sec: 120
  negative-entry-expiration-sec: 240
  direct-io: true
azstorage:
  type: block
  account-name: ACCOUNTNAME
  endpoint: https://ACCOUNTNAME.blob.core.windows.net
  container: CONTAINERNAME
  update-md5: false
  validate-md5: false
  virtual-directory: true
EOF

}

az_tags() {

  #local resource_name="$1"; check_parameter "$resource_name"

  if [ $useTags = "YES" ]; then # If use tags
    tags=(`az resource list --name $1 | jq '.[].tags | [."'"$TASK_TAG"'",."'"$DATABASE_TAG"'",."'"$USER_TAG"'",."'"$SECRET_TAG"'",."'"$PORT_TAG"'",."'"$SERVER_TAG"'"]]' | sed 's/"//g' | sed 's/,//g' | sed 's/\]//g' | sed 's/\[//g' | paste -sd " "`)
    task=${tags[0]}
    databases=${tags[1]}
    username=${tags[2]}
    secret=${tags[3]}
    port=${tags[4]}
    server=${tags[5]}
  else
    task=$fixTags_task
    databases=$fixTags_database
    username=$fixTags_user
    secret=$fixTags_bsecret
    port=$fixTags_port
  fi
}

get_connection() {

  local containerType="$1"

  if [ $containerType = "azsql" ]; then # If is Azure SQL
      if [ $useFQDN = "NO" ]; then
              server=$(nslookup "$fixTags_resource_list"".database.windows.net" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
              [[ -z "$server" ]] && echo Server Name to IP translate fail || echo IP for server "$fixTags_resource_list" is "$server"
      else
              server=$fixTags_resource_list.database.windows.net
      fi
  fi

  if [ $containerType = "cosmosmg" ]; then # If is Cosmos DB
      if [ $useFQDN = "NO" ]; then
            server=$(nslookup "$fixTags_resource_list"".mongo.cosmos.azure.com" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
            [[ -z "$server" ]] && echo Server Name to IP translate fail || echo IP for server "$fixTags_resource_list" is "$server"
      else
            server=$fixTags_resource_list.mongo.cosmos.azure.com
      fi
  fi
  
  if [ $containerType = "postgresql" ]; then # If is postgre DB
      if [ -f ${ConfigDir}/resources ]; then rm -rf ${ConfigDir}/resources; fi
      if [ $azureResources_useAutoDiscover = "YES" ]; then
          echo
          echo "*********************************** SEARCHING cloud resources **************************************"
          echo
              if [ $cloudConnection_EndPoints_useEndPoints = "YES" ]; then # azureResources_useAutoDiscover by end points
                      az postgres server list --resource-group $azureLogin_resourceGroup --query "[?privateEndpointConnections].{Name:name, PV:privateEndpointConnections}" | jq '.[].PV' > ${ConfigDir}/resources
              else # azureResources_useAutoDiscover by server name
                      az resource list  --resource-type $RESOURCES --resource-group $azureLogin_resourceGroup -o table | tail -n +3 | awk {'print $1'} > ${ConfigDir}/resources
              fi
      else
          echo "*********************************** LISTING cloud resources **************************************"
          echo
              if [ $cloudConnection_EndPoints_useEndPoints = "YES" ]; then # Resources by end points
                  pgserver=$(echo $fixTags_resource_list |fmt -1 |sed 's/,//g')
                  for i in ${pgserver[@]}
                  do
                      privend=$(az postgres server show --resource-group $azureLogin_resourceGroup --name $i |jq -r '.privateEndpointConnections[].properties.privateEndpoint.id' | rev | cut -d'/' -f 1 | rev)
                      az network private-endpoint show -g $azureLogin_resourceGroup --name $privend |jq -r '.customDnsConfigs[].fqdn' >> ${ConfigDir}/resources
                  done
              else # Resources by server name
                      echo $fixTags_resource_list |fmt -1 |sed 's/,//g' >> ${ConfigDir}/resources
              fi
              #sed -i 's/$/.postgres.database.azure.com/' ${ConfigDir}/resources #agrega domino
              sed -i 's/.postgres.database.azure.com//' ${ConfigDir}/resources   #quita dominio
      fi
      if [ ! -s ${ConfigDir}/resources ]; then  echo !!! There are no resource to process, exiting; exit 1; fi
  fi

  if [ $containerType = "blobstorage" ]; then # If is blobstorage
          if [ $azureResources_useAutoDiscover = "YES" ]; then
                  echo
                  echo "*********************************** SEARCHING All cloud resources **************************************"
                  echo
                  STA=($(az storage account list --query "[].{name:name}" --output tsv))
                  for i in ${STA[@]}
                  do
                          privep=($(az storage account show --name $i --query privateEndpointConnections | jq -r '.[].name'))
                          if [ ! -z "$privep" ]; then
                          echo $i >> ${ConfigDir}/swoconfig
                          else
                          echo "The STA $i has not Private end Point and cannot make backup" >>  ${ConfigDir}/stanotprivep
                          fi
                  done
          else
                  echo "*********************************** LISTING cloud resources **************************************"
                  echo
                  STA=$(echo $fixTags_resource_list |fmt -1 |sed 's/,//g')
                  for i in ${STA[@]}
                  do
                          privep=($(az storage account show --name $i --query privateEndpointConnections | jq -r '.[].name'))
                          if [ ! -z "$privep" ]; then
                          echo $i >> ${ConfigDir}/swoconfig
                          else
                          echo "no priep $i"
                          echo "The STA $i has not Private end Point and cannot make backup" >>  ${ConfigDir}/stanotprivep
                          fi
                  done
          fi
  fi

  if [ $containerType = "adls" ]; then # If is adls
          if [ -f ${ConfigDir}/swoconfig ]; then rm -rf ${ConfigDir}/swoconfig; fi
          if [ $azureResources_useAutoDiscover = "YES" ]; then
                  echo
                  echo "*********************************** SEARCHING All cloud resources **************************************"
                  echo
                  STA=($(az storage account list --query "[].{name:name}" --output tsv))
                  for i in ${STA[@]}
                  do
                          privep=($(az storage account show --name $i --query privateEndpointConnections | jq -r '.[].name'))
                          HnsEnabled=($(az storage account show --query isHnsEnabled --name $i | sed 's/"//g'))
                          if [[ ! -z "$privep" && ! -z "$HnsEnabled" ]]; then
                          echo $i >> ${ConfigDir}/swoconfig
                          else
                          echo "The STA $i has not Private end Point and cannot make backup" >>  ${ConfigDir}/stanotprivep
                          fi
                  done
          else
                  echo "*********************************** LISTING cloud resources **************************************"
                  echo
                  STA=$(echo $fixTags_resource_list |fmt -1 |sed 's/,//g')
                  echo $STA
                  for i in ${STA[@]}
                  do
                          privep=($(az storage account show --name $i --query privateEndpointConnections | jq -r '.[].name'))
                          HnsEnabled=($(az storage account show --query isHnsEnabled --name $i | sed 's/"//g'))
                          if [[ ! -z "$privep" && ! -z "$HnsEnabled" ]]; then
                          echo $i >> ${ConfigDir}/swoconfig
                          else
                          echo "no private  end point $i"
                          echo "The STA $i has not Private end Point and cannot make backup" >  ${ConfigDir}/stanotprivep
                          fi
                  done
          fi
  fi
}

get_secret() {
        echo "Trying to get secret"
        if [ $useKeyVaultSecureAccess = "YES" ]; then # IF YES we will use curl to access the keyVault, else az keyvault secret show command
        echo !!!!! Processing token from keyVaultName !!!!!
        response=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -H Metadata:true -s)
        if [ ${response:2:5} == "error" ]; then echo ERROR Getting token from keyVaultName ${keyVaultName}; exit 1; fi
                access_token=$(echo $response | python3 -c 'import sys, json; print (json.load(sys.stdin)["access_token"])')
                echo !!!!! Processing value from keyVaultName !!!!!
                response=$(curl https://${keyVaultName}.vault.azure.net/secrets/$secret?api-version=2016-10-01 -s -H "Authorization: Bearer ${access_token}")
                if [ ${response:2:5} == "error" ]; then echo ERROR  Getting value from keyVaultNames; exit 1; fi
                echo !!!!! Getting secret from keyVaultName LIST priv !!!!!
                pass=$(echo $response | python3 -c 'import sys, json; print (json.load(sys.stdin)["value"])')
                # Falta agregar un control de errores luego del procedsamiento de python3
         else
                echo !!!!! Getting secret from keyVaultName GET priv !!!!!
                pass=$(az keyvault secret show --name ${secret} --vault-name ${keyVaultName} | jq -r '.value')
                if [ -z ${pass} ]; then echo "ERROR: Unable to get $secret from keyVaultName ${keyVaultName}. EXIT "; exit 1; fi
         fi
}
