#!/bin/bash

set -e -u -o pipefail

declare PASSWORD=""
declare FILE=""

while (( $# )); do
    case "$1" in
        # --password)
        #     PASSWORD=$2
        #     shift 2
        #     ;;
        --pull-file)
            FILE=$2
            shift 2
            ;;
        *|-*|--*)
            echo "unrecognized flag $1"
            exit 1
            ;;
    esac
done

if [ -z "$FILE" ]; then
    echo "Need to path to pull secret file"
fi

# configure the crc
crc config set cpus 8
crc config set memory 10486
crc config set pull-secret-file $FILE

# this will prompt the user for a root password (sudo)
crc setup

# now start the new crc instance
crc start