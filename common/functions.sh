# Functions.sh:
version="1.0.0 "
# Check parameter function, if parameter is not set, exit with error

echo_and_run() { echo "$*" ; "$@" ; }

check_parameter() {
  local param="$1"
  
  if [ -z "$param" ]; then
    echo "Error: Parameter is not set."
    exit 1
  fi
}

operationType(){
    case "${1}" in
      "ADD") TYPE=ADD;;
      "DELETE") TYPE=DELETE;;
      *) echo "Missing value, please use ADD or DELETE"; exit;;
    esac
}

# Function to get the current date and time in the format YYYY-MM-DDTHH:MM:SSZ
get_current_datetime() {
  date +%Y-%m-%d.%T
}

# Function to log a message to the console and a log file
echo_and_log_message() {
  local message="$1"
  local log_file="$2"
  
  current_time=$(get_current_datetime)

  if [ ! -z "$log_file" ]; then
    echo "$current_time: $message" | tee "$log_file"
  fi
}

# Function to log a message to the console 
log_message() {
  local message="$1"
  local log_file="$2"
  
  current_time=$(get_current_datetime)

  if [ ! -z "$log_file" ]; then
    echo "$current_time: $message" | tee -a "$log_file"
  fi
}

check_file_exists() {
  local file="$1"
  
  if [ ! -f "$file" ]; then
    echo "Error: File $file does not exist, exiting."
    exit 1
  fi
}

is_empty() {
  local string="$1"
  if [ -z "$string" ]; then
    echo "String is empty"
    exit 1
  fi
}

container_exists() {
  container_name="$1"
  runtime="$2"
  
  if $runtime ps -a --format "{{.Names}}" | grep -wq "$container_name"; then
    echo "Exists"
  else
    echo "Notexist"
  fi
}


create_temp_file() {
  local temp_file=$(mktemp)
  
  echo "$temp_file"
  return
}

delete_temp_file() {
  local temp_file="$1"
  
  if [ -f "$temp_file" ]; then
    rm -f "$temp_file"
  fi
}

# Function to create a directory if it doesn't exist
create_directory() {
  local directory="$1"
  
  if [ ! -d "$directory" ]; then
    mkdir -p "$directory"
    return $directory
  fi
}

# Function to download a file from a URL
download_file() {
  local url="$1"
  local destination_file="$2"
  
  curl -L "$url" -o "$destination_file"
}

# Function to upload a file to a URL
upload_file() {
  local url="$1"
  local source_file="$2"
  
  curl -X PUT -H "Content-Type: application/octet-stream" --data-binary "@$source_file" "$url"
}

# Function to delete a file
delete_file() {
  local file="$1"
  
  if [ -f "$file" ]; then
    rm -f "$file"
  fi
}

# Function to remove a directory and its contents
remove_directory() {
  local directory="$1"
  
  if [ -d "$directory" ]; then
    rm -rf "$directory"
  fi
}

# Function to create a temporary directory
create_temp_directory() {
  local temp_dir=$(mktemp -d -p .)
  echo "$temp_dir"
}

# Function to clean up temporary files
clean_up_temp_files() {
  local temp_dir="$1"
  
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
  fi
}



replaceAccountKey() {
local inputFile="$1"; check_parameter "$inputFile";
local original="$2"; check_parameter "$original";
local replacement="$3"; check_parameter "$replacement";

sed -i "s/$original/$replacement/g" "$inputFile"
}

json_remove_space() {
    # Read and transform the JSON file

    local input_file=$1
    local output_file=$2

    jq 'walk(if type == "string" then gsub(" "; "") else . end)' "$input_file" > $output_file
}

# Function to parse JSON and create variables
json2env() {
    local prefix=$1
    local json=$2

    # Loop through each key-value pair in the JSON
    while IFS="=" read -r key value; do
        # Remove quotes from key and value
        key=$(echo "$key" | tr -d '"')
        value=$(echo "$value")
        
        # Create full key with prefix
        full_key="${prefix}${key}"

        if [[ $value == \{* ]]; then
            # If the value is a JSON object, call json2env recursively
            json2env "${full_key}_" "$(echo "$value" | jq -c '.')"
	    
        else
            # Create variables dynamically
            declare "$full_key=$value"
            # echo the variable (optional)
            echo "$full_key=$value" >> $temp_file
        fi
    done < <(echo "$json" | jq -r 'to_entries | .[] | "\(.key)=\(.value | tostring)"')
}

json_parsing() {
    local input_json="$1"  # Input JSON file path.
    local output_file="$2"  # Output JSON file path.

    # Remove spaces from the JSON file and save it to the output file.
    json_remove_space "$input_json" "$output_file"
 
    # Create a temporary file to store environment variables.
    local temp_file
    temp_file=$(create_temp_file)
 
    # Convert the JSON content to environment variables and save them in the temporary file.
    json2env "" "$(jq -c '.' "$output_file")" "$temp_file"
 
    # Source the temporary file to load the environment variables into the current shell.
    . "$temp_file"

    json_backupTags "$output_file" "backupTags"
    json_backupTags "$output_file" "fixValues"

    delete_temp_file $temp_file
}

json_print() {
    local input_json="$1"  # Input JSON file path.
    local output_file="$2"  # Output JSON file path.
 
    # Remove spaces from the JSON file and save it to the outp
    json_remove_space "$input_json" "$output_file"
 
    # Create a temporary file to store environment variables.
    local temp_file
    temp_file=$(create_temp_file)
 
    # Convert the JSON content to environment variables and sa
    json2env "" "$(jq -c '.' "$output_file")" "$temp_file"
 
    # Source the temporary file to load the environment variab
    . "$temp_file"

    json_backupTags "$output_file" "backupTags"
    json_backupTags "$output_file" "fixValues"

    cat "$temp_file"
    delete_temp_file $temp_file
}


prebuild() {

  local IMAGE_SOURCE=$1
  local VERSION=$2
  local CONTAINER_NAME=$3
  local dockerfile=$4
  local containerType=$5
  local ConfigDir=$6

  post_install_script_file="$temp_dir/post_install.sh"
  
  echo "FROM $IMAGE_SOURCE:$VERSION" > $dockerfile
      
  if [ $cloudConnection_certs_useCerts == "YES" ]; then                                                       # If certificates are used
    echo "#Certs configs" >> Dockerfile
    echo "COPY src/packages/DockerEmbebed/Certificates/$CERTFILE /etc/pki/ca-trust/source/anchors/" >> $dockerfile
    echo "RUN update-ca-trust" >> $dockerfile
  fi

  if [ $cloudConnection_proxy_useProxy == "YES" ]; then                                                      # If proxy is used
    echo "#Proxy config" >> $dockerfile
    echo "ENV HTTP_PROXY=$cloudConnection_proxy_proxyHttpName" >> $dockerfile
    echo "ENV HTTPS_PROXY=$cloudConnection_proxy_proxyHttpsName" >> $dockerfile
    echo "ENV http_proxy=$cloudConnection_proxy_proxyHttpName" >> $dockerfile
    echo "ENV https_proxy=$cloudConnection_proxy_proxyHttpsName" >> $dockerfile
    echo "ENV NO_PROXY=$cloudConnection_proxy_noProxy" >> $dockerfile
  fi
  
  backupCommand=$(jq -r ".\"$containerType\".backupCommand" $output_file)
  restoreCommand=$(jq -r ".\"$containerType\".restoreCommand" $output_file)
  
  echo "RUN mkdir -p $ScriptDir/common" >> $dockerfile
  echo "COPY code/$backupCommand $ScriptDir/$backupCommand" >> $dockerfile
  echo "COPY code/$restoreCommand $ScriptDir/$restoreCommand" >> $dockerfile
  echo "COPY code/post-mount.sh $ScriptDir/post-mount.sh" >> $dockerfile
  echo "COPY common/* $ScriptDir/common/" >> $dockerfile
  echo "RUN chmod 755 $ScriptDir/*.sh" >> $dockerfile

  echo "COPY $jsonfiles/dps-setup.json $ConfigDir" >> $dockerfile
    
  if [[ $containerType == "minio" ]]; then
    if [ -d files/$containerType ]; then echo "COPY files/$containerType $ScriptDir"  >> $dockerfile; fi
    if [ -f files/$containerType/ca_certs ]; then echo "COPY /etc/pki/ca-trust/source/anchors/ca_certs"  >> $dockerfile; fi
  fi
  
  # Postinstall script creates mount point for dump (when needed)
  echo "#/bin/bash" > $post_install_script_file
  echo "mkdir -p /$datadomain_RootBackupDir" >> $post_install_script_file        # Create backup mount point inside container

  if [ $datadomain_mountType == "ddboostfs" ]; then  powerProtectMount $post_install_script_file; fi              # If ddboost fs is used

  # This script wll be used as ENTYPOINT
  BackupPaaS_script_file="BackupPaaS.sh"
  systemctl_BackupPaaS_script_file="systemctl_BackupPaaS.sh"

  if [ $avamar_useAvamar == "YES" ]; then avamarDockerfile $dockerfile $ConfigDir $post_install_script_file       # If avamar is used
  else
      echo "tail -f /dev/null" > $BackupPaaS_script_file
  fi                                                    
  
  echo "COPY $BackupPaaS_script_file $ConfigDir" >> $dockerfile

  echo "Docker config dir is $ConfigDir"; echo $ConfigDir > $temp_dir/seed.txt
  echo "Docker script dir is $ScriptDir"; echo $ScriptDir >> $temp_dir/seed.txt
  echo "COPY $temp_dir/seed.txt /tmp" >> $dockerfile

  # Add the systemd service to run the additional script
  echo "COPY $systemctl_BackupPaaS_script_file /etc/systemd/system/BackupPaaS.service" >> $dockerfile

  # Manually enable the service by creating the necessary symlink
  echo "RUN ln -s /etc/systemd/system/BackupPaaS.service /etc/systemd/system/multi-user.target.wants/BackupPaaS.service" >> $dockerfile

  # Create a directory for systemd runtime
  echo "VOLUME [ \"/sys/fs/cgroup\" ]" >> $dockerfile

  echo "ENTRYPOINT [ \"/usr/lib/systemd/systemd\" ]" >> $dockerfile
  echo "RUN chmod 755 $ConfigDir/*.sh" >> $dockerfile

  delete_file $output_file
}

build() {
  local CONTAINER_NAME=$1
  local IMAGE_TARGET=$2
  local IMAGE_TARGET_VERSION=$3
  local dockerfile=$4
  $runtime build -t $IMAGE_TARGET:$IMAGE_TARGET_VERSION -f $dockerfile . --network host 
  delete_file /tmp/seed.txt
  delete_file $BackupPaaS_script_file
  delete_file $systemctl_BackupPaaS_script_file
  delete_file $post_install_script_file
}

deployLocal() {
  local CONTAINER_NAME=$1
  local IMAGE_TARGET=$2
  local IMAGE_TARGET_VERSION=$3
  if [ $avamar_useAvamar = "YES" ]; then
    containersParameters="-d -it --device /dev/fuse -P --cap-add SYS_ADMIN  --network host --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:ro"
  else
    containersParameters="-d -it --device /dev/fuse --cap-add SYS_ADMIN  --network host --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:ro"
  fi
  $runtime run --hostname $CONTAINER_NAME --name $CONTAINER_NAME $containersParameters $IMAGE_TARGET:$IMAGE_TARGET_VERSION /bin/bash
}

help() {
    LIST=$(grep containerType docs/containerTypes.csv | sed -n 1'p' | tr ',' '\n' | grep -v containerType | awk '{print}' ORS='|')
    echo -e "${RED}Please use the below flags:
    -c          container type  $LIST
    -i          source image 
    -v          version of the source image
    -t          name of the target image
    -d          container installation directory (i.e. /dockerclient)${NC}"
    echo -e "${RED}Examples: 1- azsql: ./m-dps-setup.sh -d azsql -i azal-v 1.0 -t azsql${NC}"
}

validate() {
        grep -F -q $1 <<EOF
        $LIST
EOF
}

validate_version() {
    case ${1,,} in
      latest) VERSION=latest;;
      1.0) VERSION=1.0;;
      2.0) VERSION=2.0;;
      3.0) VERSION=3.0;;
      4.0) VERSION=4.0;;
      5.0) VERSION=5.0;;
      6.0) VERSION=6.0;;
      7.0) VERSION=7.0;;
      8.0) VERSION=8.0;;
      9.0) VERSION=9.0;;
      10.0) VERSION=10.0;;
      11.0) VERSION=11.0;;
      12.0) VERSION=12.0;;
      *) VERSION=ERROR;;
      esac
    echo ${VERSION}
    }

colors() {
  GREEN='\033[1;32m'
  RED="\033[1;31m"
  NC='\033[0m' # No Color
  export GREEN RED NC
}



join_json_files() {

  if [ ! -f ${jsonfiles}/dps-setup.json ]; then

    echo Missing dps-setup.json file in folder ${jsonfiles}. Trying to create a new one from dps-setup-*.json files.

    # Check if any required JSON files are missing
    for file in $(ls -1 ${jsonfiles}/dps-setup*.json); do
        if [[ ! -f "${file}" ]]; then
            echo -e "${RED}Json file ${file} missing in ${jsonfiles} folder${NC}"
            exit 1
        fi
    done

    # Combine all JSON files in the folder matching the pattern dps-setup*.json
    jq -s 'reduce .[] as $item ({}; . * $item)' ${jsonfiles}/dps-setup*.json > ${jsonfiles}/dps-setup.json
 
  else

    echo File dps-setup.json already exists in folder ${jsonfiles}. This will be used

  fi

}

header() {
  local version=$1
  local facility=$2
  echo -e "\n"
  echo !!!!! $(get_current_datetime) Starting job ver ${version}, facility ${facility}  !!!!!
  echo -e "\n"
}

# Just the footer function
footer() {
  local version=$1
  local facility=$2
  echo -e "\n"
  echo !!!!! $(get_current_datetime) Finishing job ver ${version}, facility ${facility}  !!!!!
  echo -e "\n"
}

##
## Checks if the pattern "--include" exists in the avtar.cmd file and if so, check if the folder specified after "--include" exists
##
checkAvtarInclude () {

    if [ -f ${ConfigDir}/var/avtar.cmd ]; then include=$(grep -e '--include' ${ConfigDir}/var/avtar.cmd); fi
    if [[ ${#include} -gt 0 ]]; then
            folder=$(echo ${include} | rev | cut -d'=' -f 1 | rev)
            folder=${folder%/*}
            if [ ! -d ${folder} ]; then
                    echo "Directory ${folder} doesn't exists."; exit 1
            else
                    echo "Directory ${folder} exists."
            fi
    fi
}

change_containerType_json_keys() {

  local jsonfile=$1
  local dockertype=$2
  
  old_value=$(jq -r '.containerType' ${jsonfiles}/dps-setup.json)
  jq --arg old_val "$old_value" --arg new_val "$dockertype" \
     '(.containerType | select(. == $old_val)) = $new_val' "${jsonfiles}/dps-setup.json" > tmp.json && mv -f tmp.json "${jsonfiles}/dps-setup.json"
}

change_json_keys() {
  local fileName=$1
  local keyName=$2
  local newValue=$3

  # Update the JSON file with the new value for the specified key

  jqarg="--arg parameter $newValue"
  jqkey=" $keyName = \$parameter"
  jqkeytest="$keyName"

  jqTemplate="jq $jqarg '$jqkey' $fileName" 
  eval $jqTemplate > tmp.$$.json
  mv -f tmp.$$.json "$fileName"; delete_file tmp.$$.json 
}

check_vault_and_secret() {
    local vault_value="$1"  # Capture the vault value passed as a parameter.
    local secret_value="$2"  # Capture the secret value passed as a parameter.
 
    # Define the valid vaults and secrets.
    local vaults="$3"
    local secrets="$4"
 
    # Convert the comma-separated strings into arrays for easy comparison.
    IFS=',' read -r -a vault_array <<< "$vaults"
    IFS=',' read -r -a secret_array <<< "$secrets"
 
    # Check if the vault value exists in the vault array.
    local vault_found=false
    for vault in "${vault_array[@]}"; do
        if [[ "$vault" == "$vault_value" ]]; then
            vault_found=true
            break
        fi
    done
 
    # Check if the secret value exists in the secret array.
    local secret_found=false
    for secret in "${secret_array[@]}"; do
        if [[ "$secret" == "$secret_value" ]]; then
            secret_found=true
            break
        fi
    done
 
    # If both vault and secret are found, echo the success message.
    if $vault_found && $secret_found; then
        echo "doNotBackup"
    else 
        echo "doBackup"
    fi
}

json_backupTags() {
    local json_string="$1"  # Capture the JSON string passed as a parameter.
    local tagToParse="$2"

    # Use jq to parse the JSON and extract keys and values.
    # Ensure jq is installed on the system to run this function successfully.
    if ! command -v jq &> /dev/null; then
        echo "jq is required but not installed. Please install jq to use this function."
        exit 1
    fi

    # Extracting values from the JSON and assigning them to variables.
    if [ $tagToParse = "backupTags" ]; then 
        backupTags=$(cat "$json_string" | jq -c '.backupTags[]')
        # Loop through each backup tag and assign to variables.
        for tag in $backupTags; do
            local type=$(echo "$tag" | jq -r '.type')
            local value=$(echo "$tag" | jq -r '.value')

            # Dynamically create variable names based on the type.
            case "$type" in
                user)
                    bck_user="$value"
                    backupTags_user="$value"; echo "backupTags_user=""$backupTags_user" >> "$temp_file"
                    ;;
                port)
                    bck_port="$value"
                    backupTags_port="$value"; echo "backupTags_port=""$backupTags_port" >> "$temp_file"
                    ;;
                database)
                    bck_database="$value"
                    backupTags_database="$value"; echo "backupTags_database=""$backupTags_database" >> "$temp_file"
                    ;;
                task)
                    bck_task="$value"
                    backupTags_task="$value"; echo "backupTags_task=""$backupTags_task" >> "$temp_file"
                    ;;
                bsecret)
                    bck_bsecret="$value"
                    backupTags_bsecret="$value"; echo "backupTags_bsecret=""$backupTags_bsecret" >> "$temp_file"
                    ;;
                rsecret)
                    bck_rsecret="$value"
                    backupTags_rsecret="$value"; echo "backupTags_rsecret=""$backupTags_rsecret" >> "$temp_file"
                    ;;
                *)
                    echo "Unknown type: $type"
                    ;;
            esac
        done
    else
        fixTags=$(cat "$json_string" | jq -c '.fixValues[]')
        # Loop through each backup tag and assign to variables.
        for tag in $fixTags; do
            local type=$(echo "$tag" | jq -r '.type')
            local value=$(echo "$tag" | jq -r '.value')

            # Dynamically create variable names based on the type.
            case "$type" in
                user)
                    bck_user="$value"
                    fixTags_user="$value"; echo "fixTags_user=""$fixTags_user" >> "$temp_file"
                    ;;
                port)
                    bck_port="$value"
                    fixTags_port="$value"; echo "fixTags_port=""$fixTags_port" >> "$temp_file"
                    ;;
                resource_list)
                    resource_list="$value"
                    fixTags_resource_list="$value"; echo "fixTags_resource_list=""$fixTags_resource_list" >> "$temp_file"
                    ;;
                database)
                    bck_database="$value"
                    fixTags_database="$value"; echo "fixTags_database=""$fixTags_database" >> "$temp_file"
                    ;;
                task)
                    bck_task="$value"
                    fixTags_task="$value"; echo "fixTags_task=""$fixTags_task" >> "$temp_file"
                    ;;
                bsecret)
                    bck_bsecret="$value"
                    fixTags_bsecret="$value"; echo "fixTags_bsecret=""$fixTags_bsecret" >> "$temp_file"
                    ;;
                rsecret)
                    bck_rsecret="$value"
                    fixTags_rsecret="$value"; echo "fixTags_rsecret=""$fixTags_rsecret" >> "$temp_file"
                    ;;
                *)
                    echo "Unknown type: $type"
                    ;;
            esac
        done
    fi

}

folders() {
    # SERVICE_TYPE - The type of service we are running. Extracted from dps-setup.json.
    SERVICE_TYPE=$containerType
    # DOCKERNAME - The name of the container. Extracted from dps-setup.json.
    DOCKERNAME=$container_containerName
    # LogDir - The directory where the log files are stored.
    LogDir=$ConfigDir/var
    # RootBackupDir - The root backup directory. Extracted from dps-setup.json.
    RootBackupDir=/$datadomain_RootBackupDir
    # ServiceBackupDir - The service backup directory.
    ServiceBackupDir=${RootBackupDir}/$containerType
    # BackupDir - The directory where the backups are stored.
    BackupDir=${ServiceBackupDir}/backups
    # BackupDirByCont - The directory where the backups are stored by dockername.
    BackupDirByCont=${ServiceBackupDir}/backups/$container_containerName
    # BackupDirByContDate - The directory where the backups are stored by dockername and date.
    BackupDirByContDate=${ServiceBackupDir}/backups/$container_containerName-`date +%Y%m%d`
    # BackupDirByContDateHour - The directory where the backups are stored by dockername, date, and hour.
    BackupDirByContDateHour=${ServiceBackupDir}/backups/$container_containerName-`date +%Y%m%d%H`
    # RestoreDir - The directory where the restores are stored.
    RestoreDir=${ServiceBackupDir}/restore
    # OldBackupDir - The directory where the old backups are stored.
    OldBackupDir=${ServiceBackupDir}/old
    # LogFile - The log file for this script.
    LogFile=${LogDir}/${SERVICE_TYPE}_`date +%Y%m%d.%T`.log
    # Checks if the directories exist and creates them if not.
    if [ ! -d $ConfigDir ]; then echo $ConfigDir does not exist; exit 1; fi
    if [ ! -d ${RootBackupDir} ]; then mkdir ${RootBackupDir}; fi
    if [ ! -d ${ServiceBackupDir} ]; then mkdir ${ServiceBackupDir}; fi
    if [ ! -d ${BackupDir} ]; then mkdir ${BackupDir}; fi
    if [ ! -d ${LogDir} ]; then mkdir ${LogDir}; fi
    if [ -n "$DOCKERNAME" ]; then
            if [ ! -d ${BackupDirByCont} ]; then mkdir ${BackupDirByCont}; fi
            if [ ! -d ${BackupDirByContDate} ]; then mkdir ${BackupDirByContDate}; fi
            if [ ! -d ${BackupDirByContDateHour} ]; then mkdir ${BackupDirByContDateHour}; fi
    fi
    if [ ! -d ${RestoreDir} ]; then mkdir ${RestoreDir}; fi
    if [ ! -d ${OldBackupDir} ]; then mkdir ${OldBackupDir}; fi
    # End of folder & file section
}

# Function to check if the container already exists
check_container() {
    local container_name="$1"
    local runtime="$2"
    if $runtime ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo "Error: A container with the name '${container_name}' already exists."
        exit 1
    fi
}

check_container_runtime() {
  if ! command -v docker &> /dev/null && ! command -v podman &> /dev/null; then
        echo "Error: Neither Docker nor Podman is installed. Please install one of them to proceed."
        exit 1
  fi
  if command -v podman &> /dev/null; then
        echo "podman"
    else
        # Podman is not installed. Asumming docker
        run=docker
  fi
}

# Function to check if a container is running
check_container_status() {
    local container_name="$1"

    runtime=$(check_container_runtime)

    # Check container status
    if $runtime inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null | grep -q "true"; then
        echo "running"
    else
        echo "notrunning"
    fi
}

# Function to pull the image
pull_image() {
    local image_name="$1"
    local runtime="$2"
    echo "Pulling image '${image_name}'..."
    if ! $runtime pull "${image_name}"; then
        echo "Error: Failed to pull image '${image_name}'."
        exit 1
    fi
}

# Function to run the container
run_container() {
    local container_name="$1"
    local image_name="$2"
    local db_user="$3"
    local db_password="$4"
    local db_name="$5"
    local port="$6" # Add the port parameter
    local runtime="$7"
    echo "Running container '${container_name}'..."
    if ! $runtime run -d \
        --name "${container_name}" \
        --network mynetwork \
        -e POSTGRES_USER="${db_user}" \
        -e POSTGRES_PASSWORD="${db_password}" \
        -e POSTGRES_DB="${db_name}" \
        -p "${port}:${port}" \
        "${image_name}"; then
        echo "Error: Failed to run container '${container_name}'."
        exit 1
    fi
    echo "Container '${container_name}' is running on port ${port}."
}

# Function to parse syslog.cfg and extract values
parse_config() {
    local config_file="syslog.ini"
    declare -A config_values

    

    # Read the file line by line
    while IFS='=' read -r key value; do
        # Remove leading/trailing whitespace and skip empty lines or comments
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        config_values[$key]="$value"
    done < <(grep -A 8 '^\[database\]' "$config_file" | grep -v '\[')

    # Export values as environment variables (optional)
    db_container_ip="${config_values[container_ip]}"
    db_container="${config_values[container]}"
    db_from_image="${config_values[from_image]}"
    user="${config_values[user]}"
    dbname="${config_values[dbname]}"
    port="${config_values[port]}"
    logfile="${config_values[logfile]}"

    # Read the file line by line
    while IFS='=' read -r key value; do
        # Remove leading/trailing whitespace and skip empty lines or comments
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        config_values[$key]="$value"
    done < <(grep -A 3 '^\[vizualize\]' "$config_file" | grep -v '\[')

    # Export values as environment variables (optional)
    app_container="${config_values[container]}"
    app_from_image="${config_values[from_image]}"
    container_network="${config_values[container_network]}"
}
