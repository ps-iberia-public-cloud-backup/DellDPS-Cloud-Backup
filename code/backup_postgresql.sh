#!/bin/bash
# Avamar script for backup in Azure PostgreSQL databases.
version="1.0.10"
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

# Log file path
log_file="$LogDir/$scriptName.log"
log_message "Backup started" $log_file

# Get the list of Azure resources
get_connection $containerType
cat ${ConfigDir}/resources | while read linea
do
set -a $linea " "
        if [ "${1::1}" != "#" ] ; then
                if [ $postgresql_FlexibleServer == "YES" ]; then
                PGServerType="flexible-server"
                PGDumpUserName="--username=${username}"
                PGTableExclude="-T "cron.*""
                echo Trying to backup PostgreSQL Flexible Servers
        else
                PGServerType=""
                PGDumpUserName="--username=${username}@${linea}"
                PGTableExclude=""
                echo Trying to backup PostgreSQL Single Servers
        fi
        # Get secret from keyvault
        get_secret
        if [ "$databases" = "ALL" ]; then
                dbs=(`az postgres $PGServerType db list  --resource-group $azureLogin_resourceGroup --server-name $linea -o table | tail -n +3 | awk {'print $(NF-1)'} | grep -v azure_maintenance | grep -v azure_sys `)
        else
                dbs=$databases
        fi
        if [ $postgresql_useDumpall = "NO" ]; then
                for db in ${dbs[@]}; do
                        if [ $postgresql_backupCreationScript = "YES" ]; then
                                echo PGPASSWORD=******** PGSSLMODE=require pg_dump -v -s --host=$linea.postgres.database.azure.com $PGDumpUserName --dbname=$db -f ${BackupDirByCont}/$container_containerName.${linea}.$db.$(date +%Y%m%d%H%M%S).sql
                                PGPASSWORD=${pass} PGSSLMODE=require pg_dump -v -s --host=$linea.postgres.database.azure.com $PGDumpUserName --dbname=$db -f ${BackupDirByCont}/$container_containerName.${linea}.$db.$(date +%Y%m%d%H%M%S).sql
                        fi
                        echo PGPASSWORD=******** PGSSLMODE=require pg_dump -Fc -v --host=${linea}.postgres.database.azure.com $PGDumpUserName --dbname=$db $PGTableExclude  -f ${BackupDirByCont}/$container_containerName.${linea}.$db.$(date +%Y%m%d%H%M%S).dump
                        PGPASSWORD=${pass} PGSSLMODE=require pg_dump -Fc -v --host=$linea.postgres.database.azure.com $PGDumpUserName --dbname=$db $PGTableExclude -f ${BackupDirByCont}/$container_containerName.${linea}.$db.$(date +%Y%m%d%H%M%S).dump
                        if [ "$?" != "0" ] ; then echo ERROR Unable to make pg_dump for db $db on server ${linea}.postgres.database.azure.com; exit 1; fi
                        echo !!!!! Running  process  $containerType Data Base  $db !!!!!
                done
        else
                if [ $postgresql_FlexibleServer == "YES" ]; then
                        echo ERROR pg_dumpall is not available on PostgreSQL Flexible Servers; exit 1
                elif [ $postgresql_FlexibleServer == "NO" ]; then
                        echo PGPASSWORD=******** PGSSLMODE=require pg_dumpall --host=${linea}.postgres.database.azure.com $PGDumpUserName --exclude-database=azure_sys --exclude-database=azure_maintenance -f ${BackupDirByCont}/$container_containerName.${linea}.$(date +%Y%m%d%H%M%S).dump
                        PGPASSWORD=${pass} PGSSLMODE=require pg_dumpall --host=$linea.postgres.database.azure.com $PGDumpUserName --exclude-database=azure_sys --exclude-database=azure_maintenance -f ${BackupDirByCont}/$container_containerName.${linea}.$(date +%Y%m%d%H%M%S).dump
                        if [ "$?" != "0" ] ; then echo ERROR Unable to make pg_dumpall on server ${linea}.postgres.database.azure.com; exit 1; fi

                fi
                if [ $postgresql_backupCreationScript = "YES" ]; then
                        echo WARNING "postgresql_backupCreationScript" JSON key enforce backup script creation and is not compatible with "postgresql_useDumpall" JSON key
                fi
        fi
fi
done

delete_file output.json
# Azure logout
az_logout $version $containerType
log_message "Backup finished" log_file
