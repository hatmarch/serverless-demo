#!/bin/bash

set -e -u -o pipefail

declare PROJECT="coolstore"
declare REBUILD=""
declare SKIP_PRE=""

# whether to setup a completely working coolstore with quarkus jvm and native services
declare FULL=""

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
        -f|--full)
            FULL=true
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
    echo "rebuilding all coolstore components (NOTE: This is not supported and you may hit issues with coolstore-ui node project)"
    $DEMO_HOME/scripts/build-project.sh
fi

if [[ -z "$FULL" ]]; then
    echo "Not doing a full installation, see walkthrough script"
else
    echo "Doing a full installation"

    oc project $PROJECT

    # create kafka eventing
    oc apply -f $DEMO_HOME/payment-service/knative/kafka-event-source.yaml 

    # create payment build
    oc new-build  --image-stream="openshift/redhat-openjdk18-openshift:1.5" --binary --name=payment    

    # create native payment build (and associated image stream)
    oc new-build quay.io/quarkus/ubi-quarkus-native-binary-s2i:19.2.0 --binary --name=payment-native
    
    # import initial payment build
    oc import-image --from quay.io/mhildenb/homemade-serverless-java:1.0 \
        $(oc get is/payment -o jsonpath='{.status.dockerImageRepository}'):initial  
    
    # import initial payment native build
    oc import-image --from quay.io/mhildenb/homemade-serverless-native:1.0 \
        $(oc get is/payment-native -o jsonpath='{.status.dockerImageRepository}'):quarkus-initial

    # tag in payment image stream
    oc tag payment-native:quarkus-initial payment:quarkus-native 
    
    # create service
    kn service create payment --image $(oc get is/payment -o jsonpath='{.status.dockerImageRepository}'):initial --revision-name "{{.Service}}-{{.Generation}}" -l app.kubernetes.io/part-of=focus 

    # create second revision
    kn service update payment --image $(oc get is/payment -o jsonpath='{.status.dockerImageRepository}'):quarkus-native --revision-name "{{.Service}}-{{.Generation}}"
fi

# add payment build configs?