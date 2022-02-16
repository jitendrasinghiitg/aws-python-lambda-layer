#!/bin/bash

set -e

LAMBDA_LAYER_SIZE_LIMIT="250"
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

get_folder_size_in_mb () {
  CURRENT_FOLDER_SIZE="`du -hs $1`"
  CURRENT_FOLDER_SIZE=${CURRENT_FOLDER_SIZE%M*}
  echo "Current Foldersize: $CURRENT_FOLDER_SIZE MB"
}


print_commands () {
  echo "#############################################################"
  echo -e "$2"
  echo "#############################################################"
}


version=$(python -V 2>&1 | grep -Po '(?<=Python )(.+)')
if [[ -z "$version" ]]
then
    echo "No Python!"
fi


print_commands "" "${GREEN} Creating layer compatible with python version $version ${ENDCOLOR}"

pip3 install -r /lambda_layer/requirements.txt -t python -U

get_folder_size_in_mb "/lambda_layer/python"

if [[ $CURRENT_FOLDER_SIZE -gt $LAMBDA_LAYER_SIZE_LIMIT ]]; then
        print_commands "" "${GREEN} Removing tests folders as Folder is bigger than $LAMBDA_LAYER_SIZE_LIMIT MB${ENDCOLOR}"

        find /lambda_layer/python -name "tests" -type d -exec rm -rdf {} +
        find /lambda_layer/python -name "*-info" -type d -exec rm -rdf {} +

        find /lambda_layer/python -type f -name '*.pyc' | while read f; do n=$(echo $f | sed 's/__pycache__\///' | sed 's/.cpython-38//'); cp $f $n; done;

        find /lambda_layer/python -type d -a -name '__pycache__' -print0 | xargs -0 rm -rf
        find /lambda_layer/python -type f -a -name '*.py' -print0 | xargs -0 rm -f

        print_commands "" "${GREEN} Removing Libraries already there in lambda ${ENDCOLOR}"
        rm -rdf /lambda_layer/python/boto3/
        rm -rdf /lambda_layer/python/botocore/
        rm -rdf /lambda_layer/python/dateutil/
        rm -rdf /lambda_layer/python/jmespath/
        rm -rdf /lambda_layer/python/docutils/
        rm -rdf /lambda_layer/python/s3transfer/

        get_folder_size_in_mb "/lambda_layer/python"
        if [[ $CURRENT_FOLDER_SIZE -gt $LAMBDA_LAYER_SIZE_LIMIT ]]; then
          print_commands "" "${GREEN} Stiping .so files ${ENDCOLOR}"
          find /lambda_layer/python  -name "*.so" | xargs strip
        else
          echo "striping not required"
        fi

else
        echo "Folder is smaller than $LAMBDA_LAYER_SIZE_LIMIT MB"
fi


get_folder_size_in_mb "/lambda_layer/python"

print_commands "" "${GREEN} Zipping zip files for creating lambda layer${ENDCOLOR}"

zip -r ./output/python.zip ./python/*

print_commands "" "${GREEN} Lambda Layer Created Now Cleaning Temporary Folder${ENDCOLOR}"

rm -r /lambda_layer/python/*