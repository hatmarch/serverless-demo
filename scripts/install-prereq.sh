#!/bin/bash

set -e -u -o pipefail

declare SKIP_KAFKA_EVENTING=""
declare SKIP_EVENTING=""
declare FOR_CRC=""
declare PROJECT="user1-cloudnativeapps"

while (( $# )); do
    case "$1" in
        --skip-knative-kafka-eventing)
            SKIP_KAFKA_EVENTING="true"
            shift
            ;;
        --skip-all-eventing
            SKIP_KAFKA_EVENTING="true"
            SKIP_EVENTING="true"
            shift
            ;;
        --crc)
            FOR_CRC="true"
            shift
            ;;
        -*|--*)
            echo "unrecognized flag $1"
            exit 1
            ;;
        *)
            PROJECT=$1
            shift
            ;;
    esac
done

oc get ns $PROJECT 2>/dev/null  || { 
    oc new-project $PROJECT 
}

command.wait_for_crd()
{
    local CRD=$1
    local PROJECT=$(oc project -q)
    if [[ "${2:-}" ]]; then
        # set to the project passed in
        PROJECT=$2
    fi

    # Wait for the CRD to appear
    while [ -z "$(oc get $CRD 2>/dev/null)" ]; do
        sleep 1
    done 
    oc wait --for=condition=Established $CRD --timeout=6m -n $PROJECT
}

#
# Subscribe to Operators
#

# install the kafka operator (AMQStreams)
oc apply -f "$DEMO_HOME/install/kafka/subscription.yaml" 

# install the serverless operator
oc apply -f "$DEMO_HOME/install/serverless/subscription.yaml" 

# install the knative eventing operator
if [ -z "$SKIP_EVENTING" ]; then
    oc apply -f "$DEMO_HOME/install/knative-eventing/subscription.yaml"
else
    echo "SKIPPING installation of knative eventing at user's request"
fi

# install the kafka knative eventing operator
if [ -z "$SKIP_KAFKA_EVENTING" ]; then
    oc apply -f "$DEMO_HOME/install/kafka-eventing/subscription.yaml"
else
    echo "SKIPPING installation of kafka eventing at user's request."
fi

#
# Install Kafka Instances
#

# make sure CRD is available before adding CRs
echo "Waiting for the operator to install the Kafka CRDs"
command.wait_for_crd "crd/kafkas.kafka.strimzi.io"

if [ -z "$FOR_CRC" ]; then
    # use the default parameter values
    oc process -f "$DEMO_HOME/install/kafka/kafka-template.yaml" | oc apply -f -
else
    # install lighter weight cluster on CRC
    oc process -f "$DEMO_HOME/install/kafka/kafka-template.yaml" -p REPLICA_COUNT=1 -p MIN_ISR=1 | oc apply -f -
fi

# install the necessary kafka instance and topics
oc apply -f "$DEMO_HOME/install/kafka/kafka-order-topic.yaml" -n $PROJECT
oc apply -f "$DEMO_HOME/install/kafka/kafka-payment-topic.yaml" -n $PROJECT

#
# Install Serving
#

echo "Waiting for the operator to install the Knative CRDs"
command.wait_for_crd "crd/knativeservings.operator.knative.dev"

oc apply -f "$DEMO_HOME/install/serverless/cr.yaml"

echo "Waiting for the knative serving instance to finish installing"
oc wait --for=condition=InstallSucceeded knativeserving/knative-serving --timeout=6m -n knative-serving

#
# Install Knative Eventing
#
if [ -z "$SKIP_EVENTING" ]; then
    echo "Waiting for the operator to install the Knative Event CRD"
    command.wait_for_crd "crd/knativeeventings.eventing.knative.dev"

    oc apply -f "$DEMO_HOME/install/knative-eventing/knative-eventing.yaml" 
    echo "Waiting for the knative eventing instance to finish installing"
    oc wait --for=condition=InstallSucceeded knativeeventing/knative-eventing -n knative-eventing --timeout=6m
else
    echo "Skipped Knative Eventing configuration at user's request"
fi

if [ -z "$SKIP_KAFKA_EVENTING" ]; then
    # This where kafka eventing would be installed
    oc apply -f "$DEMO_HOME/install/kafka-eventing/kafka-eventing.yaml"
else
    echo "Skipping Kafka Eventing configuration at the user's request"
fi

#
# Ensure Kafka cluster is ready
#

# wait until the cluster is deployed
echo "Waiting up to 30 minutes for kafka cluster to be ready"
oc wait --for=condition=Ready kafka/my-cluster --timeout=30m -n $PROJECT
echo "Kafka cluster is ready."
