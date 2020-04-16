#!/bin/bash

set -e -u -o pipefail

declare PROJECT="coolstore"
declare REBUILD=""
declare SKIP_PRE=""

while (($#)); do
    case $1 in
        -p|--project)
            PROJECT=$2
            shift 2
            ;;
        -b|--rebuild)
            REBUILD="true"
            shift
            ;;
        --skip-prereq)
            SKIP_PRE="true"
            shift
            ;;
        *)
            echo "unrecognized flag $1"
            exit 1
            ;;
    esac
done

#create the project if it doesn't already exist
oc get ns $PROJECT 2>/dev/null  || { 
    oc new-project $PROJECT 
}

if [ -z "$SKIP_PRE" ]; then
    # then install the pre-requisites
    $DEMO_HOME/scripts/install-prereq.sh $PROJECT
fi

# Install all the coolstore services, routes, build and deployment configs, etc
oc process -f $DEMO_HOME/install/cool-store-no-payment-template.yaml -p PROJECT=$PROJECT | oc apply -f - -n $PROJECT

# Fix up all the routes in the cluster
oc project $PROJECT
$DEMO_HOME/scripts/route-fix.sh

if [[ -z "$REBUILD" ]]; then
    echo "updating all images"
    # Fix up all image streams by pointing to pre-built images (which should trigger deployments)
    $DEMO_HOME/scripts/image-stream-setup.sh
else
    echo "rebuilding all coolstore components (NOTE: This is not supported)"
    $DEMO_HOME/scripts/build-project.sh
fi

# add payment build configs?