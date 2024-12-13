
#/bin/bash
#version 2.0.10
#update docker and create new image
repohome=${PWD}

#Function to check if podman is installed and use podman o docker command
function check_podman_installed() {
 if command -v podman &> /dev/null; then
        echo "Podman is installed."
        run=podman
    else
        echo "Podman is not installed."
        run=docker
    fi
}
check_podman_installed

function main(){
updatedocker $@
}
function updatedocker(){
    while getopts n:i:t:v:f:u:c:e:o: option; do
        case ${option} in
            t) DOCKERTYPE=${OPTARG};;
            n) DOCKERNAME=${OPTARG};;
            i) IMAGENEW=${OPTARG};;
            v) VERSION=${OPTARG};;
            f) FILES=${OPTARG};;
            u) IMAGEUPDATE=${OPTARG};;
            c) CLASS=${OPTARG};;
            e) COMMAND=${OPTARG};;
            o) COMMANDOP=${OPTARG};;
            ?) help;;
        esac
    done
        if [[ $@ != *"-n "* && $@ != *"-t "* ]]; then  echo "please use -n to specify the DOCKERNAME TO UPGRADE or -t to UPGRADE ALL DOCKER TYPE" ;  exit 1 ; fi
        if [[ $@ = *"-n "* && $@ = *"-t "* ]]; then  echo "please use -n  or -t do not ALL" ;  exit 1 ; fi
#        if [[ $@ != *"-f "* ]]; then  echo "please use -f to specify the FILES FULL PATH TO UPGRADE" ;  exit 1 ; fi
source=$repohome/src/avamar/azure/CLI/
target=/dockerclient/etc/scripts
#Execute commad on docker
if [[ $@ = *"-e "* ]]; then
        if [[ $@ = *"-n "* ]]; then
                $run exec -it $DOCKERNAME bash -c ''"${COMMAND}"' '"${COMMANDOP}"''
        elif [[ $@ = *"-t "* ]]; then
                dockerlist=$($run ps -a |grep -i $DOCKERTYPE |awk '{print $NF}')
                for j in ${dockerlist[@]}
                do
                $run exec -it $j bash -c ''"${COMMAND}"' '"${COMMANDOP}"''
                done
        fi
fi
#Update docker files
if [[ $@ = *"-f "* ]]; then
        if [[ $@ = *"-n "* ]]; then
                for i in $(echo "$FILES" | tr "," "\n")
                do
                $run cp ${source}$i "$DOCKERNAME":${target}/$i
                done
                $run exec -it $DOCKERNAME bash -c 'chmod 755 '"${target}"'/*.*'
        elif [[ $@ = *"-t "* ]]; then
                dockerlist=$($run ps -a |grep -i $DOCKERTYPE |awk '{print $NF}')
                for j in ${dockerlist[@]}
                do
                        for i in $(echo $FILES | tr "," "\n")
                        do
                        $run cp ${source}$i "$j":${target}/$i
                        done
                $run exec -it $j bash -c 'chmod 755 '"${target}"'/*.*'
                done
        fi
fi
#Create New Image
if [[ $@ = *"-i "* ]]; then  echo "se creará  nueva imagen $IMAGENEW"
if [[ $@ != *"-n "* ]]; then  echo "please use -n to specify the DOCKERNAME to use like Template" ;  exit 1 ; fi
if [[ $@ != *"-v "* ]]; then  echo "please use -v to specify the NEW IMAGE VERSION" ;  exit 1 ; fi
if [[ $@ = *"-u "* && $@ = *"-i "* ]]; then  echo "please use -u  or -i do not ALL" ;  exit 1 ; fi
$run commit $DOCKERNAME $IMAGENEW:$VERSION
fi

#Upgrade docker with new image
if [[ $@ = *"-u "* ]]; then  echo "docker $DOCKERNAME will be upgraded with image $IMAGEUPDATE"
        if [[ $@ = *"-t "* ]]; then  echo "plese do not use -t to update docker, you can indicate several DOCKERNAME using , like DOCKER1, DOCKER2" ;  exit 1 ; fi
        if [[ $@ != *"-n "* ]]; then  echo "please use -n to specify the DOCKERNAME to Upgrade" ;  exit 1 ; fi
        if [[ $@ = *"-i "* ]]; then  echo "please use -u  or -i do not ALL" ;  exit 1 ; fi
        if [[ $@ != *"-v "* ]]; then  echo "please use -v to specify the IMAGE VERSION" ;  exit 1 ; fi
        if [[ $@ != *"-c "* ]]; then  echo "please use -c to specify the CLASS of docker" ;  exit 1 ; fi
        for i in $(echo "$DOCKERNAME" | tr "," "\n")
        do
                #backup current docker files
                [ ! -d ../jsonfiles/updated/ ] && mkdir ../jsonfiles/updated/
                filesupdate=../jsonfiles/updated/$i/
                if [ -d $filesupdate ]; then rm -rf $filesupdate; fi
                [ ! -d $filesupdate ] && mkdir $filesupdate
                $run cp "$i":/dockerclient/dps-setup.json $filesupdate
                $run cp "$i":/dockerclient/var/ "$filesupdate"
#                $run cp "$i":/dockerclient/var/.avagent "$filesupdate"var/
                #Update json
                template=../jsonfiles/dps-setup-app.json
                DOCKERNAME=$(echo $i | sed 's/\(.*\)_.*/\1/')
                DOCKERTYPE=`jq '.containerType' "$filesupdate"dps-setup.json  | sed 's/"//g'`
                KEYVAULT=`jq '.keyVaultName' "$filesupdate"dps-setup.json  | sed 's/"//g'`
                USER=`jq '.fixValues[] | select(.type=="user")|.value' "$filesupdate"dps-setup.json | sed 's/"//g'`
                RESOURCELIST=`jq '.fixValues[] | select(.type=="resource_list")|.value' "$filesupdate"dps-setup.json | sed 's/"//g'`
                SECRET=`jq '.fixValues[] | select(.type=="secret")|.value' "$filesupdate"dps-setup.json | sed 's/"//g'`
                RSGROUP=`jq '.resourceGroup' "$filesupdate"dps-setup.json  | sed 's/"//g'`
                AUTODISCOVER=`jq '.azureResources.useAutoDiscover' "$filesupdate"dps-setup.json | sed 's/"//g'`
                SUSCRIPTIONID=`jq '.subscription.subscriptionID' "$filesupdate"dps-setup.json | sed 's/"//g'`
                RESOURCETYPE=`jq '.azureResources.resourceType' "$filesupdate"dps-setup.json | sed 's/"//g'`
                if [ "$DOCKERNAME" = "" ] || [ "$DOCKERNAME" = "null" ]; then echo "Review the dps-setup.json file of the original docker because DOCKERNAME is empty or null value"; exit; fi
                if [ "$DOCKERTYPE" = "" ] || [ "$DOCKERTYPE" = "null" ]; then echo "Review the dps-setup.json file of the original docker because DOCKERTYPE is empty or null value"; exit; fi
                 if [ "$DOCKERTYPE" != "blobstorage" ]; then
                        if [ "$KEYVAULT" = "" ] || [ "$KEYVAULT" = "null" ]; then echo "Review the dps-setup.json file of the original docker because KEYVAULT is empty or null value"; exit; fi
                else
                        KEYVAULT=xxxxx
                fi
                if [ "$USER" = "" ] || [ "$USER" = "null" ]; then echo "Review the dps-setup.json file of the original docker because USER is empty or null value"; exit; fi
                if [ "$RESOURCELIST" = "" ] || [ "$RESOURCELIST" = "null" ]; then echo "Review the dps-setup.json file of the original docker because RESOURCELIST is empty or null value"; exit; fi
                if [ "$SECRET" = "" ] || [ "$SECRET" = "null" ]; then echo "Review the dps-setup.json file of the original docker because SECRET is empty or null value"; exit; fi
                if [ "$RSGROUP" = "" ] || [ "$RSGROUP" = "null" ]; then
                        RSGROUP=`jq '.azureLogin.resourceGroup' "$filesupdate"dps-setup.json  | sed 's/"//g'`
                        if [ "$RSGROUP" = "" ] || [ "$RSGROUP" = "null" ]; then echo "Review the dps-setup.json file of the original docker because RSGROUP is empty or null value"; exit; fi
                fi
                if [ "$AUTODISCOVER" = "" ] || [ "$AUTODISCOVER" = "null" ]; then echo "Review the dps-setup.json file of the original docker because AUTODISCOVER is empty or null value"; exit; fi
                if [ "$SUSCRIPTIONID" = "" ] || [ "$SUSCRIPTIONID" = "null" ]; then
                        SUSCRIPTIONID=`jq '.azureLogin.subscription.subscriptionID' "$filesupdate"dps-setup.json | sed 's/"//g'`
                        if [ "$SUSCRIPTIONID" = "" ] || [ "$SUSCRIPTIONID" = "null" ]; then echo "Review the dps-setup.json file of the original docker because SUSCRIPTIONID is empty or null value"; exit; fi
                fi
                if [ "$RESOURCETYPE"" = "" ] || [ "RESOURCETYPE"" = "null" ]; then echo "Review the dps-setup.json file of the original docker because RESOURCETYPE is empty or null value"; exit; fi
                # Json parsing
                [ ! -d ../jsonfiles/$DOCKERTYPE/ ] && mkdir ../jsonfiles/$DOCKERTYPE/
                jqDNMarg="--arg dockername \$DOCKERNAME"
                jqDNM=".container.containerName = \$dockername"
                jqDTYarg="--arg type \$DOCKERTYPE"
                jqDTY="| .containerType = \$type"
                jqRSLarg="--arg resource \""$RESOURCELIST"\""
                jqRSL="| ( .fixValues[] | select(.type==\"resource_list\") ).value = \$resource"
                jqSCRarg="--arg secret \$SECRET"
                jqSCR="| ( .fixValues[] | select(.type==\"secret\") ).value = \$secret"
                jqRSGarg="--arg rsg \$RSGROUP"
                jqRSG="| .resourceGroup = \$rsg"
                jqAKVarg="--arg akv \$KEYVAULT"
                jqAKV="| .keyVaultName = \$akv"
                jqUSRarg="--arg usr \$USER"
                jqUSR="| ( .fixValues[] | select(.type==\"user\") ).value = \$usr"
                jqATDarg="--arg autodiscover \$AUTODISCOVER"
                jqATD="| .azureResources.useAutoDiscover = \$autodiscover"
                jqSUSarg="--arg suscription \$SUSCRIPTIONID"
                jqSUS="| .subscription.subscriptionID = \$suscription"
                jqRSTarg="--arg resourcetype \$RESOURCETYPE"
                jqRST="| .azureResources.resourceType = \$resourcetype"

                jqTemplate="jq  $jqDNMarg $jqDTYarg $jqRSLarg $jqSCRarg $jqRSGarg $jqAKVarg $jqUSRarg $jqATDarg $jqSUSarg $jqRSTarg '$jqDNM $jqDTY $jqRSL $jqSCR $jqRSG $jqAKV $jqUSR $jqATD $jqSUS $jqRST' $template > ../jsonfiles/$DOCKERTYPE/"$i".json"
                eval $jqTemplate
                jq -s '.[0] * .[1] * .[2] * .[3]' ../jsonfiles/dps-setup-coms.json ../jsonfiles/$CLASS.json ../jsonfiles/dps-setup-ave-ddve.json ../jsonfiles/$DOCKERTYPE/"$i".json > "$filesupdate"dps-setup.json
                #Create new docker
                $run stop $i
                $run rename $i "$i"_old
                imageID=`$run images |grep -i $IMAGEUPDATE |grep -i $VERSION |awk '{print $3}'`
                NEWDOCKERNAME=$(echo "$i" | tr _ -)
                sed -i -e 's/_/-/g' "$filesupdate"avamar/.avagent
                $run run -P --hostname "$NEWDOCKERNAME" --name "$NEWDOCKERNAME" -d -it --device /dev/fuse --cap-add SYS_ADMIN --restart unless-stopped --network host $imageID
                if [ $? -ne 0 ]; then echo docker run error, exit; exit 1; fi
                $run cp "$filesupdate"avamar/. "$NEWDOCKERNAME":/dockerclient/var
                $run cp "$filesupdate"dps-setup.json "$NEWDOCKERNAME":/dockerclient/dps-setup.json
                mv "$filesupdate"dps-setup.json "$filesupdate"dps-setup.json$(date +%Y-%m-%d)
                $run exec -it "$NEWDOCKERNAME" bash -c 'if [ -f /etc/fstab ]; then rm -rf /etc/fstab; fi'
                $run exec -it "$NEWDOCKERNAME" bash -c 'if [ -f /opt/emc/boostfs/lockbox/boostfs.lockbox ]; then rm -rf /opt/emc/boostfs/lockbox/*.*; fi'
                $run exec "$NEWDOCKERNAME" bash -c '/dockerclient/post_install.sh -u'
                if [ $? -ne 0 ]; then echo docker files cp  error, exit; exit 1; fi
                if  [[ ( $DOCKERTYPE == "azsql" || $DOCKERTYPE == "cosmosql" || $DOCKERTYPE == "cvision"  || $DOCKERTYPE == "cosmosmg" || $DOCKERTYPE == "atlas" || $DOCKERTYPE == "postgresql" || $DOCKERTYPE == "keyvault" || $DOCKERTYPE == "kafka" || $DOCKERTYPE == "mariadb" || $DOCKERTYPE == "mysql" ) ]]; then
                        echo "--run-at-start-clause=timeout-seconds=72000" > "$filesupdate"$DOCKERNAME.avtar
                        echo "--exclude=*" >> "$filesupdate"$DOCKERNAME.avtar
                        echo "--include=/Backup/$DOCKERTYPE/backups/$DOCKERNAME**" >> "$filesupdate"$DOCKERNAME.avtar
                        $run cp "$filesupdate"$DOCKERNAME.avtar "$NEWDOCKERNAME":/dockerclient/var/avtar.cmd
                        if [ $? -ne 0 ]; then echo docker .avtar cp  error, exit; exit 1; fi
                fi
        done
fi
}

function help(){
    echo "Please use the below flags:
    -t <Docker type> (exclude -n) azsql|blobstorage|cosmosql|cvision|databriks|datafactory|adls|eventhub|filestorage|hdinsight|keyvault|cosmosmg|atlas|netappstorage|postgresql|redis
    -n <Docker name. Can be list current with "docker ps -a" command> (exclude -t)
    -i <New image name to create form a docker updated. Can be list current with "docker images" command. Optional>
    -v <New image version. Required with -i and - u>
    -f <Name of files to upgrade allocated on src/avamar/azure/CLI, include /sources if this is the location>
    -u <Image to use to upgrade docker with a new image>
    -c <Docker class> PRE|PRO|DEV
    -e <commad that you want to execute on docker>
    -o <if an option is required by -c (command)> "
    echo "Example: ./updatedocker.sh -n <Docker name> -i <New image name> -v <New image version> -f <File list> "
    echo "Example: ./updatedocker.sh -n <Docker name> -u <New image for upgrade> -v <New image version> "
}
if [ $# -eq 0 ]; then
help
exit 1
else
main $@
fi
