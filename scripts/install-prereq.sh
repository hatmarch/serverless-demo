#!/bin/bash

set -e -u -o pipefail

declare SKIP_KAFKA_EVENTING=""
declare FOR_CRC=""
declare KAFKA_PROJECT="kn-demo-dev"
declare INSTALL_SERVERLESS="true"

while (( $# )); do
    case "$1" in
        --skip-knative-kafka-eventing)
            SKIP_KAFKA_EVENTING="true"
            shift
            ;;
        --skip-serverless)
            INSTALL_SERVERLESS=""
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
            KAFKA_PROJECT=$1
            shift
            ;;
    esac
done

oc get ns $KAFKA_PROJECT 2>/dev/null  || { 
    oc new-project $KAFKA_PROJECT 
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

# install OpenShift Pipelines (tekton)
echo "Installing the OpenShift Pipelines Operator"
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator-rh
  namespace: openshift-operators
spec:
  channel: ocp-4.6
  installPlanApproval: Automatic
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# install the serverless operator
if [[ -n "$INSTALL_SERVERLESS" ]]; then
    echo "Installing Serverless Operator"
    oc apply -f "$DEMO_HOME/install/serverless/subscription.yaml" 
else
    echo "Skipping installation of Serverless Operator"
fi

# install the kafka operator (AMQStreams)
oc apply -f "$DEMO_HOME/install/kafka/subscription.yaml" 

# NOTE: knative eventing operator is now included as part of the OpenShift serverless operator

#
# Install Kafka Instances
#

# make sure CRD is available before adding CRs
echo "Waiting for the operator to install the Kafka CRDs"
command.wait_for_crd "crd/kafkas.kafka.strimzi.io"

if [ -z "$FOR_CRC" ]; then
    # use the default parameter values
    oc process -f "$DEMO_HOME/install/kafka/kafka-template.yaml" | oc apply -n ${KAFKA_PROJECT} -f -
else
    # install lighter weight cluster on CRC
    oc process -f "$DEMO_HOME/install/kafka/kafka-template.yaml" -p REPLICA_COUNT=1 -p MIN_ISR=1 | oc apply -n ${KAFKA_PROJECT} -f -
fi

# # install the necessary kafka instance and topics
# oc apply -f "$DEMO_HOME/install/kafka/kafka-order-topic.yaml" -n $PROJECT
# oc apply -f "$DEMO_HOME/install/kafka/kafka-payment-topic.yaml" -n $PROJECT

#
# Install Serving
#
if [[ -n "$INSTALL_SERVERLESS" ]]; then
    echo "Waiting for the operator to install the Knative CRDs"
    command.wait_for_crd "crd/knativeservings.operator.knative.dev"

    oc apply -f "$DEMO_HOME/install/serverless/cr.yaml"

    echo "Waiting for the knative serving instance to finish installing"
    oc wait --for=condition=InstallSucceeded knativeserving/knative-serving --timeout=6m -n knative-serving

    #
    # Install Knative Eventing
    #
    echo "Waiting for the operator to install the Knative Event CRD"
    command.wait_for_crd "crd/knativeeventings.operator.knative.dev"

    oc apply -f "$DEMO_HOME/install/knative-eventing/knative-eventing.yaml" 
    echo "Waiting for the knative eventing instance to finish installing"
    oc wait --for=condition=InstallSucceeded knativeeventing/knative-eventing -n knative-eventing --timeout=6m
fi


if [ -z "$SKIP_KAFKA_EVENTING" ]; then
    # This where kafka eventing would be installed
    sed "s/%KAFKA_PRJ%/${KAFKA_PROJECT}/g" "$DEMO_HOME/install/knative-eventing/kafka-eventing.yaml" | oc apply -f -
else
    echo "Skipping Kafka Eventing configuration at the user's request"
fi

#
# Install Gitea Operator
#
declare giteaop_prj=gpte-operators
echo "Installing gitea operator in ${giteaop_prj}"
oc apply -f $DEMO_HOME/install/gitea/gitea-crd.yaml
oc apply -f $DEMO_HOME/install/gitea/gitea-cluster-role.yaml
oc get ns $giteaop_prj 2>/dev/null  || { 
    oc new-project $giteaop_prj --display-name="GPTE Operators"
}

# create the service account and give necessary permissions
oc get sa gitea-operator -n $giteaop_prj 2>/dev/null || {
  oc create sa gitea-operator -n $giteaop_prj
}
oc adm policy add-cluster-role-to-user gitea-operator system:serviceaccount:$giteaop_prj:gitea-operator

# install the operator to the gitea project
oc apply -f $DEMO_HOME/install/gitea/gitea-operator.yaml -n $giteaop_prj
sleep 2
oc rollout status deploy/gitea-operator -n $giteaop_prj


#
# Ensure Kafka cluster is ready
#

# wait until the cluster is deployed
echo "Waiting up to 30 minutes for kafka cluster to be ready"
oc wait --for=condition=Ready kafka/my-cluster --timeout=30m -n $KAFKA_PROJECT
echo "Kafka cluster is ready."
