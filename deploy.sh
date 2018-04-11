#!/bin/bash

# Centos 6.9 repro steps

# NOTES:
# - Assumes Azure CLI 2.0 and Python 2.7 or greater installed
# - Assumes az login was executed

set -e

RANDOM_STRING=$(< /dev/urandom tr -dc a-z0-9 | head -c 5)
RANDOM_PWD=$(< /dev/urandom tr -dc 'a-zA-Z0-9!@#$%^&' | head -c 30)
USER_NAME="testAdmin"
TEMPLATE_FILE="azuredeploy.json"
RESOURCE_GROUP="noreboot-test-rg-${RANDOM_STRING}"
LOCATION="westus"
VALIDATE_ONLY=false

usage() 
{
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo "    -l <REGION>        [Required]: Location in which to create resources."
    echo "    -v                 Set VALIDATE_ONLY flag to true and perform template validation only."
    echo
    echo "Example:"
    echo
    echo "  For validation only:"
    echo "      $0 -v -l westus"
    echo 
    echo "  For deployment:"
    echo "      $0 -l westus"
    echo
}

while getopts "vl:" opt; do
    case ${opt} in
        # Set Resources Location
        l )
            LOCATION=$OPTARG
            echo "    Location: $LOCATION"
            ;;
        # Validate
        v )
            VALIDATE_ONLY=true
            echo "    Validate: $VALIDATE_ONLY"
            ;;
        h  ) usage; exit 0;;
        \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
        *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac
done
if [ $OPTIND -eq 1 ]; then echo; echo "No options were passed"; echo; usage; exit 1; fi
shift $((OPTIND -1))

az group create -n $RESOURCE_GROUP -l $LOCATION

if $VALIDATE_ONLY
then
    # Validates
    az group deployment validate -g $RESOURCE_GROUP --template-file $TEMPLATE_FILE --parameters adminUsername=${USER_NAME} adminPassword=${RANDOM_PWD} location=${LOCATION}

else
    # Deploys the Centos 6.9 VMs in parallel to demonstrate the VM deployment timeout
    az group deployment create -n "deployment-dynamic-${RANDOM_STRING}" -g $RESOURCE_GROUP --template-file $TEMPLATE_FILE --no-wait --parameters adminUsername=${USER_NAME} adminPassword=${RANDOM_PWD} location=${LOCATION}
fi

echo ""
echo "Password for ${USER_NAME} is ${RANDOM_PWD}"





