  #!/bin/bash
  # This script reads a json file and prints the keys.

source ${PWD}/common/functions.sh    # bash functions

colors
jsonfiles=jsonfiles

join_json_files 
   
## + Json parsing
    if [ -z $1  ]; then input_json="${jsonfiles}/dps-setup.json"; else input_json=$1; fi
    output_file="output.json"  # Output JSON file path.
   
    # Call the json_parsing function with the specified input and output files.
    json_print "$input_json" "$output_file" 
## - End Json parsing

delete_file output.json
