#!/bin/bash

# per the following $0 doesn't work reliably when the script is sourced:
# https://stackoverflow.com/questions/35006457/choosing-between-0-and-bash-source.  But 
# in some cases I've found BASH_SOURCE hasn't been set correctly.
declare SCRIPT=$0
if [[ "$SCRIPT" == "/bin/bash" ]]; then
    SCRIPT="${BASH_SOURCE}"
fi

if [[ -z "${SCRIPT}" ]]; then
    echo "BASH_SOURCE: ${BASH_SOURCE}, 0 is: $0"
    echo "Failed to find the running name of the script, you need to set DEMO_HOME manually"
fi

export DEMO_HOME=$( cd "$(dirname "${SCRIPT}")/.." ; pwd -P )

echo "DEMO_HOME set to $DEMO_HOME"
PROJECT_PREFIX=${PROJECT_PREFIX:-kn-demo}
echo "Project prefix is ${PROJECT_PREFIX}"
export dev_prj="${PROJECT_PREFIX}-dev"
export cicd_prj="${PROJECT_PREFIX}-cicd"
echo "Default dev project is ${dev_prj} and default cicd project is $cicd_prj"

alias cpr='tkn pr cancel $(tkn pr list -o name --limit 1 | cut -f 2 -d "/")'
alias ctr='tkn tr cancel $(tkn tr list -o name --limit 1 | cut -f 2 -d "/")'

# shorthand for creating a pipeline run file and watching the logs
pr () {
    FILE="$1"
    oc create -f $FILE && tkn pr logs -L -f
}

tskr () {
    FILE="$1"
    oc create -f $FILE && tkn tr logs -L -f
}

aws-up() {
    local CLUSTER_NAME=${1:-${CLUSTERNAME}}
    if [[ -z "${CLUSTER_NAME}" ]]; then
        echo "Must provide a cluster name either as parameter or in environment variable `CLUSTERNAME`"
        return 1
    fi

    local AWS_REGION=${REGION}
    if [[ -z "${AWS_REGION}" ]]; then
        echo "Must provide a region by way of REGION environment variable"
        return 1
    fi

    aws ec2 start-instances --instance-ids --region=${AWS_REGION} \
        $(aws ec2 describe-instances --region ${AWS_REGION} --query 'Reservations[*].Instances[*].{Instance:InstanceId}' --output text --filters "Name=tag-key,Values=kubernetes.io/cluster/${CLUSTER_NAME}-*" "Name=instance-state-name,Values=stopped")
}

aws-down() {
    local CLUSTER_NAME=${1:-${CLUSTERNAME}}
    if [[ -z "$CLUSTER_NAME" ]]; then
        echo "Must provide a cluster name either as parameter or in environment variable `CLUSTERNAME`"
        return 1
    fi

    local AWS_REGION=${REGION}
    if [[ -z "${AWS_REGION}" ]]; then
        echo "Must provide a region by way of REGION environment variable"
        return 1
    fi

    aws ec2 stop-instances --instance-ids --region ${AWS_REGION} \
        $(aws ec2 describe-instances --region ${AWS_REGION} --query 'Reservations[*].Instances[*].{Instance:InstanceId}' --output text --filters "Name=tag-key,Values=kubernetes.io/cluster/${CLUSTER_NAME}-*" "Name=instance-state-name,Values=running") 
}


EXTERNAL_KAFKA_ENDPOINT=$(oc get kafka my-cluster -o=jsonpath='{.status.listeners[?(@.type=="external")].bootstrapServers}{"\n"}' -n $dev_prj 2>/dev/null)
if [[ -n ${EXTERNAL_KAFKA_ENDPOINT} ]]; then
    echo "Setting up local environment to reach kafka cluster"
        
    # Get cert info for truststore to use when accessing Kafka endpoint
    oc extract secret/my-cluster-cluster-ca-cert -n $dev_prj --keys=ca.crt --to=- > /tmp/ca.crt
    keytool -import -trustcacerts -alias root -file /tmp/ca.crt -keystore $DEMO_HOME/docker-secrets/truststore.jks -storepass password -noprompt

    # override configuration variables for use with config functionality in quarkus payment service
    export mp_messaging_outgoing_payments_bootstrap_servers=${EXTERNAL_KAFKA_ENDPOINT}
    export mp_messaging_incoming_orders_bootstrap_servers=${EXTERNAL_KAFKA_ENDPOINT}
else
    echo "WARNING: No external kafka cluster could be found at $(oc whoami --show-server 2>/dev/null)"
fi



echo "Welcome to the serverless-demo!"