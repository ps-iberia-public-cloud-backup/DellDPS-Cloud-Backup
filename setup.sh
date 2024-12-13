#!/bin/bash

# This script is used to create a container image with backup and restore capabilities.

source common/functions.sh              # bash functions
source common/containerFunctions.sh     # functions for container creation


jsonfiles=jsonfiles

join_json_files

## + Json parsing
input_json="${jsonfiles}/dps-setup.json"  # Input JSON file path.
output_file="output.json"  # Output JSON file path.
    
# Call the json_parsing function with the specified input and output files.
json_parsing "$input_json" "$output_file" 
## - End Json parsing

jsonfile="${jsonfiles}/dps-setup.json"

temp_dir=$(create_temp_directory)
dockerfile="$temp_dir/Dockerfile"

runtime=$(check_container_runtime)

usage() {
    echo "Usage: $0 --containerType <value> --sourceImage <value> --sourceImageVersion <value> --targetImage <value> --targetImageVersion <value> [--proxy <value>] [--azresourceGroup <value>] [--aztenantId <value>] [--azservicePrincipalClientId <value>] [--azservicePrincipalClientSecret <value>] [--azsecretSPN <value>] [--azsubscriptionID <value>] [--avamarServerName <value>] [--datadomainServerName <value>] [--containerName <value>] [--azcontainerName <value>]"
    exit 1
}

# Function to validate alphabetic input
validate_alpha() {
    if [[ ! "$1" =~ ^[a-zA-Z]+$ ]]; then
        echo "Error: $2 must be alphabetic."
        usage
    fi
}

# Function to validate alphanumeric, punctuation, and symbols input
validate_alnum_punct() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9[:punct:]]+$ ]]; then
        echo "Error: $2 must be alphanumeric with punctuation and symbols."
        usage
    fi
}

# Function to validate UUID format
validate_uuid() {
    if [[ ! "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        echo "Error: $2 must be in UUID format."
        usage
    fi
}

# Function to validate FQDN format
validate_fqdn() {
    if [[ ! "$1" =~ ^([a-zA-Z0-9]+(-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$ ]]; then
        echo "Error: $2 must be a valid FQDN."
        usage
    fi
}

# Function to validate URL with port
validate_url_port() {
    if [[ ! "$1" =~ ^https:\/\/[a-zA-Z0-9.-]+:[0-9]{2,5}$ ]]; then
        echo "Error: $2 must be a secure URL with port."
        usage
    fi
}

# Flag to check if required parameters are provided
containerType_provided=false
sourceImage_provided=false
sourceImageVersion_provided=false
targetImage_provided=false
targetImageVersion_provided=false

# Parsing and validating parameters
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --containerType)
            validate_alpha "$2" "containerType"
            containerType_provided=true; containerType="$2"
            if [ ! -z "$containerType_provided" ]; then change_json_keys $jsonfile ".containerType" "$containerType"; fi
            shift 2
            ;;
        --sourceImage)
            validate_alnum_punct "$2" "sourceImage"
            sourceImage_provided=true; sourceImage="$2"
            shift 2
            ;;
        --sourceImageVersion)
            validate_alnum_punct "$2" "sourceImageVersion"
            sourceImageVersion_provided=true; sourceImageVersion="$2"
            shift 2
            ;;
        --targetImage)
            validate_alnum_punct "$2" "targetImage"
            targetImage_provided=true; targetImage="$2"
            shift 2
            ;;
        --targetImageVersion)
            validate_alnum_punct "$2" "targetImageVersion"
            targetImageVersion_provided=true; targetImageVersion="$2"
            shift 2
            ;;
        --proxy)
            validate_url_port "$2" "proxy"
            proxy="$2"
            if [ ! -z "$proxy" ]; then 
                change_json_keys $jsonfile ".cloudConnection.proxy.proxyHttpName" "$proxy"
                change_json_keys $jsonfile ".cloudConnection.proxy.proxyHttpsName" "$proxy"
            fi
            shift 2
            ;;
        --azresourceGroup)
            validate_alnum_punct "$2" "azresourceGroup"
            azresourceGroup="$2"
            if [ ! -z "$azresourceGroup" ]; then change_json_keys $jsonfile ".azureLogin.resourceGroup" "$azresourceGroup"; fi
            shift 2
            ;;
        --aztenantId)
            validate_uuid "$2" "aztenantId"
            aztenantId="$2"
            if [ ! -z "$aztenantId" ]; then change_json_keys $jsonfile ".azureLogin.tenantId" "$aztenantId"; fi
            shift 2
            ;;
        --azservicePrincipalClientId)
            validate_uuid "$2" "azservicePrincipalClientId"
            azservicePrincipalClientId="$2"
            if [ ! -z "$azservicePrincipalClientId" ]; then change_json_keys $jsonfile ".azureLogin.ServicePrincipal.servicePrincipalClientId" "$azservicePrincipalClientId"; fi
            shift 2
            ;;
        --azservicePrincipalClientSecret)
            validate_alnum_punct "$2" "azservicePrincipalClientSecret"
            azservicePrincipalClientSecret="$2"
            if [ ! -z "$azservicePrincipalClientSecret" ]; then change_json_keys $jsonfile ".azureLogin.ServicePrincipal.KeyVaultno.servicePrincipalClientSecret" "$azservicePrincipalClientSecret"; fi
            shift 2
            ;;
        --azsecretSPN)
            validate_alpha "$2" "azsecretSPN"
            azsecretSPN="$2"
            if [ ! -z "$azsecretSPN" ]; then change_json_keys $jsonfile ".azureLogin.ServicePrincipal.KeyVaultyes.secretSPN" "$azsecretSPN"; fi
            shift 2
            ;;
        --azsubscriptionID)
            validate_uuid "$2" "azsubscriptionID"
            azsubscriptionID="$2"
            if [ ! -z "$azsubscriptionID" ]; then change_json_keys $jsonfile ".azureLogin.subscription.subscriptionID" "$azsubscriptionID"; fi
            shift 2
            ;;
        --avamarServerName)
            validate_fqdn "$2" "avamarServerName"
            avamarServerName="$2"
            if [ ! -z "$avamarServerName" ]; then change_json_keys $jsonfile ".avamar.avamarServerName" "$avamarServerName"; fi
            shift 2
            ;;
        --datadomainServerName)
            validate_fqdn "$2" "datadomainServerName"
            datadomainServerName="$2"
            if [ ! -z "$datadomainServerName" ]; then change_json_keys $jsonfile ".datadomain.datadomainServerName" "$datadomainServerName"; fi
            shift 2
            ;;
        --containerName)
            validate_alnum_punct "$2" "containerName"
            containerName="$2"
            if [ ! -z "$containerName" ]; then change_json_keys $jsonfile ".container.containerName" "$containerName"; fi
            shift 2
            ;;
        --azcontainerName)
            validate_alpha "$2" "azcontainerName"
            azcontainerName="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown parameter: $1"
            usage
            ;;
    esac
done

# Check required parameters
if [ "$containerType_provided" = false ]; then
    echo "Error: --containerType is required."
    exit 1
fi
if [ "$sourceImage_provided" = false ]; then
    echo "Error: --sourceImage is required."
    exit 1
fi
if [ "$sourceImageVersion_provided" = false ]; then
    echo "Error: --sourceImageVersion is required."
    exit 1
fi
if [ "$targetImage_provided" = false ]; then
    echo "Error: --targetImage is required."
    exit 1
fi
if [ "$targetImageVersion_provided" = false ]; then
    echo "Error: --targetImageVersion is required."
    exit 1
fi

echo; echo; echo "****************"
echo  "Proxy:  ${proxy:-N/A} "
echo  "Azure Resource Group:  ${azresourceGroup:-N/A} "
echo  "Azure Tenant ID:  ${aztenantId:-N/A} "
echo  "Azure Service Principal Client ID:  ${azservicePrincipalClientId:-N/A} "
echo  "Azure Service Principal Client Secret:  ${azservicePrincipalClientSecret:-N/A} "
echo  "Azure Subscription ID:  ${azsubscriptionID:-N/A} "
echo  "Avamar Server Name:  ${avamarServerName:-N/A} "
echo  "Data Domain Server Name:  ${datadomainServerName:-N/A}  "
echo  "Container Name:  ${containerName:-N/A} "
echo  "Azure Container Name:  ${azcontainerName:-N/A}  "

# Validate if Container type is in the list
    LIST=$(grep containerType docs/containerTypes.csv | sed -n 1'p' | tr ',' '\n' | grep -v containerType)
    validate $containerType && echo "Container type is $containerType PASSED" || containerType="ERROR"
    LISTCONCATENATED=$(grep containerType docs/containerTypes.csv | sed -n 1'p' | tr ',' '\n' | grep -v containerType | awk '{print}' ORS='|')
    if [ $containerType = "ERROR" ]; then echo "ERROR Wrong Container type: Enter -d followed by some of these params \"${LISTCONCATENATED}\". help; exit 1; fi

# Validate if Container image source is in this host
    LIST=$($runtime images --format "{{json .Repository }}" | sed 's/"//g' | egrep -v "<none>|docker.io|quay.io"| sed 's/localhost\///g')
    validate $sourceImage && echo "Source image is $sourceImage PASSED" || sourceImage="ERROR"
    if [ $sourceImage = "ERROR" ]; then echo "ERROR Wrong image $sourceImage: Enter -i followed by some of these params \"${LIST}\". help; exit 1; fi
    
# Validate if source image version is in the list "latest/1.0/2.0/3.0/4.0/5.0/6.0/7.0/8.0/9.0/10.0/11.0/12.0"
    sourceImageVersion=$(validate_version $sourceImageVersion)
    if [ $sourceImageVersion = "ERROR" ]; then
      echo "ERROR Wrong source image version: Enter -v latest/1.0/2.0/3.0/4.0/5.0/6.0/7.0/8.0/9.0/10.0/11.0/12.0. Example -v latest"
   	  help
   	  exit 1;
    else
   	  echo "Source image version is $sourceImageVersion PASSED"
    fi

# Validate if target image version is in the list "latest/1.0/2.0/3.0/4.0/5.0/6.0/7.0/8.0/9.0/10.0/11.0/12.0"
    targetImageVersion=$(validate_version $targetImageVersion)
    if [ $targetImageVersion = "ERROR" ]; then
      echo "ERROR Wrong target image version: Enter -v latest/1.0/2.0/3.0/4.0/5.0/6.0/7.0/8.0/9.0/10.0/11.0/12.0. Example -v latest"
   	  help
   	  exit 1;
    else
   	  echo "Target image version is $targetImageVersion PASSED"
    fi

# Create the dockerfile
containerInstallationFolder=$($runtime image inspect $sourceImage:$sourceImageVersion --format '{{ .Annotations.InstallationFolder }}')
if [ $avamar_useAvamar == "YES" ]; then ScriptDir=$containerInstallationFolder/etc/scripts; else ScriptDir=$containerInstallationFolder; fi

# prebuild the image
echo; echo; echo "**************** Prebuild phase ****************"
echo "Target image will be $targetImage from $sourceImage/$sourceImageVersion/$containerType "
prebuild $sourceImage $sourceImageVersion $targetImage $dockerfile $containerType  $containerInstallationFolder

# Build the image
echo; echo; echo "**************** Build phase ****************"
echo "Build for Image:  $targetImage with dockerfile $dockerfile"
build $containerName $targetImage $targetImageVersion $dockerfile
echo "Container installation folder is $containerInstallationFolder"; echo $containerInstallationFolder > /tmp/seed.txt

# Deploy local
echo; echo; echo "**************** Deployment phase ****************"
echo "Deploy for container $containerName with image $targetImage:$targetImageVersion"
container_exist=$(container_exists $containerName $runtime)
if [ $container_exist = "Exists" ]; then
    echo "Container '$containerName' exists, nothing to do"
elif [ $container_exist = "Notexist" ]; then
    echo "Container '$containerName' does not exist, creating..."
    deployLocal $containerName $targetImage $targetImageVersion
fi

remove_directory $temp_dir
delete_temp_file $temp_file

