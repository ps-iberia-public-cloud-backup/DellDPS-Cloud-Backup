#!/bin/bash
# version 1.1.13
# Several podman service

shopt -s expand_aliases

# Include necessary source files
source common/functions.sh
source ~/.bash_aliases

# Function to check if podman is installed
check_podman_installed() {
  command -v podman >/dev/null 2>&1 && {
    echo "Podman is installed."
    run=podman
    return 0
  }
  echo "Podman is not installed."
  return 1
}

# Function to create podman services
create_podman_services() {
  podman generate systemd --files --name "$1"
  sudo cp "container-$1.service" "/etc/systemd/system/"
  sudo systemctl enable "container-$1.service"
  sudo systemctl start "container-$1.service"
}

runtime=$(check_container_runtime)

# Main function to create docker containers
main() {
  createdocker "$@"
}

# Function to create docker containers
createdocker() {
  # Parse command line arguments
  while getopts c:n:t:r:g:k:u:s:l: option; do
    case "${option}" in
    c)
      CLASS="${OPTARG}"
      ;;
    n)
      DOCKERNAME="${OPTARG}"
      ;;
    t)
      TYPE="${OPTARG}"
      ;;
    r)
      RESOURCE="${OPTARG}"
      ;;
    g)
      RSG="${OPTARG}"
      ;;
    k)
      AKV="${OPTARG}"
      ;;
    u)
      USR="${OPTARG}"
      ;;
    s)
      SCR="${OPTARG}"
      ;;
    l)
      LIMITS="${OPTARG}"
      ;;
    ?)
      help
      exit 1
      ;;
    esac
  done

  # Validate required arguments
  [[ -z "$CLASS" ]] && { echo "Please use -c to specify the CLASS DOCKER"; exit 1; }
  [[ -z "$DOCKERNAME" ]] && { echo "Please use -n to specify the DOCKERNAME"; exit 1; }
  [[ -z "$TYPE" ]] && { echo "Please use -t to specify the TYPE OF DOCKER"; exit 1; }
  [[ -z "$RESOURCE" ]] && { echo "Please use -r to specify the RESOURCE TO BACKUP"; exit 1; }
  [[ -z "$LIMITS" ]] && LIMITS="NO"

  template="jsonfiles/dps-setup-app.json"

  # Create directory for container type if it doesn't exist
  create_directory "jsonfiles/$TYPE/"

  # Get token from Avamar
  ##echo "!!!!! Getting token from Avamar !!!!!"
  ##response=$(curl --insecure --request POST "https://$AVAMAR_SERVER/api/oauth/token" --header 'Content-Type: application/x-www-form-urlencoded' -u "$APIUSER:$APIPASSWORD" -d "grant_type=password&username=$APIUSER&domain=/$AVAMAR_DOMAIN&password=$APIPASSWORD")
  ##if [[ "${response:2:5}" == "error" || -z "${response:2:5}" ]]; then
  ##  echo "Error getting token from Avamar"
  ##  exit 1
  ##fi
  ##access_token=$(echo "$response" | jq -r '.access_token')
  ##echo "!!!!! Starting getting port !!!!!"

  # Get free port ID
  ##portUSED=$(curl -k -X GET "https://$AVAMAR_SERVER/api/v1/clients?domain=/$AVAMAR_DOMAIN&fields=paging.port&recursive=false&size=2000" -H "accept: application/json" -H "authorization: Bearer $access_token" | jq -r '.content[].paging.port')
  ##for i in {28010..28500}; do
  ##  if [[ ! "${portUSED[*]}" =~ $i ]]; then
  ##    AVAMAR_PORT=$i
  ##    break
  ##  fi
  ##done
  AVAMAR_PORT=28010

  # Construct jq command for JSON parsing
  jq_cmd=(jq --arg dockername "$DOCKERNAME" --arg type "$TYPE" --arg resource "$RESOURCE" --arg avamarport "$AVAMAR_PORT" --arg secret "backup-$RESOURCE")
  [[ -n "$RSG" ]] && jq_cmd+=(--arg rsg "$RSG")
  [[ -n "$AKV" ]] && jq_cmd+=(--arg akv "$AKV")
  [[ -n "$USR" ]] && jq_cmd+=(--arg usr "$USR")
  [[ "$TYPE" == "atlas" ]] && jq_cmd+=(--arg atlassec "${SCR:-"back-$RESOURCE"}")

# Json parsing
jqDNarg="--arg dockername \$DOCKERNAME"
jqDN="| .container.containerName = \$dockername"
jqDTarg="--arg type \$TYPE"
jqDT=" .containerType = \$type"
jqRSarg="--arg resource \$RESOURCE"
jqRS="| ( .fixValues[] | select(.type==\"resource_list\") ).value = \$resource"
jqAParg="--arg avamarport \$AVAMAR_PORT"
jqAP="| .avamar.avamarClientPort = \$avamarport"
jqSC="| ( .fixValues[] | select(.type==\"secret\") ).value = \$secret"
if [ $TYPE = "atlas" ]; then
    jqSCRarg="--arg secret list-\$RESOURCE"
    if [[ $@ = *"-s "* ]]; then
        jqSCAarg="--arg atlassec \$SCR";
    else
        jqSCAarg="--arg atlassec back-\$RESOURCE"
    fi
    jqSCA="| .atlas.backupSecret = \$atlassec"
else
    jqSCRarg="--arg secret backup-\$RESOURCE"
fi
if [[ $@ = *"-g "* ]]; then jqRSGarg="--arg rsg \$RSG"; jqRSG="| .resourceGroup = \$rsg"; fi
if [[ $@ = *"-k "* ]]; then jqAKVarg="--arg akv \$AKV"; jqAKV="| .keyVaultName = \$akv"; fi
if [[ $@ = *"-u "* ]]; then jqUSRarg="--arg usr \$USR"; jqUSR="| ( .fixValues[] | select(.type==\"user\") ).value = \$usr"; fi
jqTemplate="jq  $jqDTarg $jqRSarg $jqDNarg $jqAParg $jqSCRarg $jqRSGarg $jqAKVarg $jqUSRarg $jqSCAarg '$jqDT $jqRS $jqDN $jqAP $jqSC $jqRSG $jqAKV $jqUSR $jqSCA' $template > ../jsonfiles/$TYPE/"$DOCKERNAME"_"$TYPE"_app.json"
is_empty $jqTemplate 
eval $jqTemplate

# Check if podman is installed and set the run command
check_podman_installed

# Run docker container with appropriate command based on podman or docker
image=`$run images |grep -iw $TYPE |grep -v commited |grep -i nonephimeral |awk '{print $3}'`
container_exist=$(container_exists "${DOCKERNAME}_${TYPE}" $type $runtime)

if [ $container_exist = "Exists" ]; then
    echo "Container '$container_name' exists."
    exit 1
elif [ $container_exist = "Notexist" ]; then
    echo "Container '$container_name' does not exist, creating..."
fi

if [[ "$run" == "podman" ]]; then
  type="podman"
  if [[ "$LIMITS" == "YES" ]]; then
    $type run -P --hostname "${DOCKERNAME}_${TYPE}" --name "${DOCKERNAME}_${TYPE}" --pids-limit "$PIDS_LIMIT" --memory "$MEMORY_LIMIT" --memory-swap "$SWAP_LIMIT" --security-opt seccomp=unconfined -d -it --device /dev/fuse --cap-add SYS_ADMIN --network host "$image"
  else
    $type run -P --hostname "${DOCKERNAME}_${TYPE}" --name "${DOCKERNAME}_${TYPE}" -d -it --device /dev/fuse --cap-add SYS_ADMIN --network host "$image"
  fi
  echo create_podman_services "${DOCKERNAME}_${TYPE}"
else
  type="docker"
  $type run -P --hostname "${DOCKERNAME}_${TYPE}" --name "${DOCKERNAME}_${TYPE}" -d -it --device /dev/fuse --cap-add SYS_ADMIN --restart unless-stopped --network host "$image"
fi

  # Check if docker run command was successful
  if [[ $? -ne 0 ]]; then
    echo "$type run error, exit"
    exit 1
  fi

  # Merge JSON files
  check_file_exists jsonfiles/dps-setup-coms.json
  check_file_exists jsonfiles/"$CLASS".json
  check_file_exists jsonfiles/dps-setup-ave-ddve.json

  jq -s '.[0] * .[1] * .[2] * .[3]' jsonfiles/dps-setup-coms.json jsonfiles/"$CLASS".json jsonfiles/dps-setup-ave-ddve.json "jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}_app.json" >"jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.json"
  delete_file "jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}_app.json"

  # Getting ConfigDir
  ConfigDir=$($type inspect $image | jq)

  # Copy JSON file to docker container
  "$type" cp "jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.json" "${DOCKERNAME}_${TYPE}":/$ConfigDir/dps-setup.json
  if [[ $? -ne 0 ]]; then
    echo "$type json cp  error, exit"
    exit 1
  fi

  # Create and copy .avagent file to docker container
  echo "--hostname=${DOCKERNAME}_${TYPE}" > "jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.avagent"
  echo "--listenport=$AVAMAR_PORT" >> "jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.avagent"
  "$type" cp "jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.avagent" "${DOCKERNAME}_${TYPE}":/$ConfigDir/var/.avagent
  if [[ $? -ne 0 ]]; then
    echo "$type .avagent cp  error, exit"
    exit 1
  fi
  rm -f "jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.avagent"

  # Create and copy avtar.cmd file to docker container for specific docker types
  if [[ "$TYPE" =~ ^(azsql|cosmosql|cvision|cosmosmg|atlas|postgresql|keyvault|kafka|mariadb|mysql)$ ]]; then
    echo "--run-at-start-clause=timeout-seconds=72000" >"jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.avtar"
    echo "--exclude=/Backup/$TYPE/backups/*" >>"jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.avtar"
    echo "--include=/Backup/$TYPE/backups/${DOCKERNAME}**" >>"jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.avtar"
    echo "--include=/$ConfigDir/dps-setup.json" >>"jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.avtar"
    "$type" cp "jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.avtar" "${DOCKERNAME}_${TYPE}":/$ConfigDir/var/avtar.cmd
    if [[ $? -ne 0 ]]; then
      echo "$type .avtar cp  error, exit"
      exit 1
    fi
    rm -f "jsonfiles/$TYPE/${DOCKERNAME}_${TYPE}.avtar"
  fi

  # Clean up lockbox files in docker container
  "$type" exec -it "${DOCKERNAME}_${TYPE}" bash -c 'rm -rf /etc/fstab /opt/emc/boostfs/lockbox/*.*; /$ConfigDir/post_install.sh'

  # Check if client is registered
  echo "Checking if client is registered; sleep 30"
  for i in {1..10}; do
    register=$(curl -k -X GET "https://$AVAMAR_SERVER/api/v1/clients?domain=/$AVAMAR_DOMAIN&fields=name,enabled,activated,registered,paging.port&filter=name==${DOCKERNAME}_${TYPE}&recursive=false" -H "accept: application/json" -H "authorization: Bearer $access_token")
    enabled=$(echo "$register" | jq -r '.content[].enabled')
    activated=$(echo "$register" | jq -r '.content[].activated')
    registered=$(echo "$register" | jq -r '.content[].registered')
    port=$(echo "$register" | jq -r '.content[].paging.port')
    if [[ "$enabled" == "true" && "$activated" == "true" && "$registered" == "true" && "$port" == "$AVAMAR_PORT" ]]; then
      echo "client ${DOCKERNAME} registered"
      return 0
    else
      echo "client ${DOCKERNAME} waiting to register"
      sleep 30
    fi
  done
  echo "ERROR client ${DOCKERNAME} not registered"
  return 1
}

# Function to display help message
help() {
  local docker_types
  docker_types=$(grep containerType docs/containerTypes.csv | sed -n 1'p' | tr ',' '\n' | grep -v containerType | awk '{print}' ORS='|')
  echo "Please use the below flags:
    -c <Docker class>        PRE|PRO|DEV
    -n <Docker name>
    -t <Docker type>        $docker_types
    -r <Resource list>
    -g <ResouceGroup Name>  This is an optional parameter
    -k <Keyvault Name>      This is an optional parameter
    -u <User Name>          This is an optional parameter
    -s <Secret Name>        This is an optional parameter for Keyvault secret name
    -l <Limits>             YES to setup max Memory, Swap and CPU limits for a Podman container. NO for a standard Podman container"
  echo "Example: ./nonephemeral.sh -c <Docker class> -n <Docker name> -t <Docker type> -r <Resource list> -g <RSG-name> -k <AKV name> -l NO"
}

# Check if any arguments are provided
if [[ $# -eq 0 ]]; then
  help
  exit 1
else
  main "$@"
fi
