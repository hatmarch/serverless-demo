#!/bin/bash

set -e -u -o pipefail

declare SKIP_KAFKA_EVENTING=""
declare PROJECT="user1-cloudnativeapps"

while (( $# )); do
    case "$1" in
        --skip-knative-kafka-eventing)
            SKIP_KAFKA_EVENTING="true"
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

oc new-project $PROJECT

#
# Subscribe to Operators
#

# install the kafka operator (AMQStreams)
oc apply -f "$DEMO_HOME/install/kafka/subscription.yaml"

# install the serverless operator
oc apply -f "$DEMO_HOME/install/serverless/subscription.yaml" 

# install the knative eventing operator
oc apply -f "$DEMO_HOME/install/knative-eventing/subscription.yaml"

# install the kafka knative eventing operator
if [[ -z "$SKIP_KAFKA_EVENTING" ]]; then
    oc apply -f "$DEMO_HOME/install/kafka-eventing/subscription.yaml"
else
    echo "SKIPPING installation of kafka eventing at user's request."
fi

#
# Install Kafka Instances
#

# make sure CRD is available before adding CRs
echo "Waiting for the operator to install the Kafka CRDs"
oc wait --for=condition=Established crd/kafkas.kafka.strimzi.io --timeout=6m

# install the necessary kafka instance and topics
oc apply -f $DEMO_HOME/install/kafka/kafka.yaml -n $PROJECT
oc apply -f $DEMO_HOME/install/kafka/kafka-order-topic.yaml -n $PROJECT
oc apply -f $DEMO_HOME/install/kafka/kafka-payment-topic.yaml -n $PROJECT

#
# Install Serving
#

echo "Waiting for the operator to install the Knative CRDs"
oc wait --for=condition=Established crd/knativeservings.operator.knative.dev --timeout=6m

oc apply -f "$DEMO_HOME/install/serverless/cr.yaml"

echo "Waiting for the knative serving instance to finish installing"
oc wait --for=condition=InstallSucceeded knativeserving/knative-serving --timeout=6m -n knative-serving

#
# Install Knative Eventing
#
echo "Waiting for the operator to install the Knative Event CRD"
oc wait --for=condition=Established crd/knativeservings.operator.knative.dev --timeout=6m
# 

oc apply -f "$DEMO_HOME/install/knative-eventing/knative-eventing.yaml" 
echo "Waiting for the knative eventing instance to finish installing"
oc wait --for=condition=InstallSucceeded knativeeventing/knative-eventing -n knative-eventing

#
#
#

#
# Ensure Kafka cluster is ready
#
# wait until the cluster is deployed
echo "Waiting up to 30 minutes for kafka cluster to be ready"
oc wait --for=condition=Ready kafka/my-cluster --timeout=30m -n $PROJECT
echo "Kafka cluster is ready."

