#!/bin/bash

remove-operator()
{
    OPERATOR_NAME=$1

    echo "Uninstalling operator: ${OPERATOR_NAME}"
    CURRENT_SERVERLESS_CSV=$(oc get sub ${OPERATOR_NAME} -n openshift-operators -o yaml | grep "currentCSV: ${OPERATOR_NAME}" | sed "s/.*currentCSV: //")
    oc delete sub ${OPERATOR_NAME} -n openshift-operators
    oc delete csv ${CURRENT_SERVERLESS_CSV} -n openshift-operators
}

remove-crds() 
{
    API_NAME=$1

    oc get crd -oname | grep "${API_NAME}" | xargs oc delete
}

echo "Uninstalling knative eventing"
oc delete knativeeventings.operator.knative.dev knative-eventing -n knative-eventing
oc delete namespace knative-eventing

echo "Uninstalling knative serving"
oc delete knativeservings.operator.knative.dev knative-serving -n knative-serving
oc delete namespace knative-serving

remove-operator "serverless-operator"

echo "Removing Serverless Operator related CRDs"
remove-crds "knative.dev"
