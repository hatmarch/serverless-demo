#!/bin/bash

set -Eeuo pipefail

declare -r SCRIPT_DIR=$(cd -P $(dirname $0) && pwd)
declare REMOVE_ALL="false"
declare PROJECT_PREFIX="kn-demo"
declare KAFKA_PROJECT=""

# declare PROJECT_PREFIX="dev-demo"
# declare KAFKA_PROJECT_IN=""

display_usage() {
cat << EOF
$0: Serverless Demo Uninstall --

  Usage: ${0##*/} [ OPTIONS ]
  
    -f         [optional] Full uninstall, removing pre-requisites
    -p <TEXT>  [optional] Project to use.  Defaults to kn-demo
    -k <TEXT>  [optional] The name of the support project (e.g. where kafka is installed).  Will default to kn-demo-dev
EOF
}

get_and_validate_options() {
  # Transform long options to short ones
#   for arg in "$@"; do
#     shift
#     case "$arg" in
#       "--long-x") set -- "$@" "-x" ;;
#       "--long-y") set -- "$@" "-y" ;;
#       *)        set -- "$@" "$arg"
#     esac
#   done

  
  # parse options
  while getopts ':k:p:fh' option; do
      case "${option}" in
          k  ) kafka_flag=true; KAFKA_PROJECT_IN="${OPTARG}";;
          p  ) p_flag=true; PROJECT_PREFIX="${OPTARG}";;
          f  ) full_flag=true;;
          h  ) display_usage; exit;;
          \? ) printf "%s\n\n" "  Invalid option: -${OPTARG}" >&2; display_usage >&2; exit 1;;
          :  ) printf "%s\n\n%s\n\n\n" "  Option -${OPTARG} requires an argument." >&2; display_usage >&2; exit 1;;
      esac
  done
  shift "$((OPTIND - 1))"

  if [[ -z "${PROJECT_PREFIX}" ]]; then
      printf '%s\n\n' 'ERROR - PROJECT_PREFIX must not be null' >&2
      display_usage >&2
      exit 1
  fi

  if [[ ${kafka_flag:-} && -z "${KAFKA_PROJECT_IN}" ]]; then
      printf '%s\n\n' 'ERROR - Support project (KAFKA_PROJECT) must not be null' >&2
      display_usage >&2
      exit 1
  fi

  KAFKA_PROJECT=${KAFKA_PROJECT_IN:-"${PROJECT_PREFIX}-dev"}
}

remove-operator()
{
    OPERATOR_NAME=$1
    OPERATOR_PROJECT=${2:-"openshift-operators"}

    echo "Uninstalling operator: ${OPERATOR_NAME} from project ${OPERATOR_PROJECT}"
    # NOTE: there is intentionally a space before "currentCSV" in the grep since without it f.currentCSV will also be matched which is not what we want
    CURRENT_CSV=$(oc get sub ${OPERATOR_NAME} -n ${OPERATOR_PROJECT} -o yaml | grep " currentCSV:" | sed "s/.*currentCSV: //")
    oc delete sub ${OPERATOR_NAME} -n ${OPERATOR_PROJECT}
    oc delete csv ${CURRENT_CSV} -n ${OPERATOR_PROJECT}
}

remove-crds() 
{
    API_NAME=$1

    oc get crd -oname | grep "${API_NAME}" | xargs oc delete
}

main() {
    # import common functions
    . $SCRIPT_DIR/common-func.sh

    trap 'error' ERR
    trap 'cleanup' EXIT SIGTERM
    trap 'interrupt' SIGINT

    get_and_validate_options "$@"

    # Delete main project
    dev_prj="${PROJECT_PREFIX}-dev"
    echo "Deleting project $dev_prj"
    oc delete all --all -n ${dev_prj} || true
    oc delete project "${dev_prj}" || true
    
    echo "Uninstalling Kafka project $KAFKA_PROJECT"
    oc delete project "${KAFKA_PROJECT}" || true

    cicd_prj="${PROJECT_PREFIX}-cicd"
    echo "Uninstalling cicd project ${cicd_prj}"
    oc delete project "${cicd_prj}" || true

    # delete the checluster before deleting the codeready project
    oc delete checluster --all -n codeready || true

    # delete the codeready project as well as any projects created for a given user
    oc get project -o name | grep codeready | xargs oc delete || true

    if [[ "${full_flag:-""}" ]]; then
        echo "Uninstalling knative eventing"
        oc delete knativekafkas.operator.serverless.openshift.io knative-kafka -n knative-eventing || true
        oc delete knativeeventings.operator.knative.dev knative-eventing -n knative-eventing || true
        
        oc delete namespace knative-eventing || true

        echo "Uninstalling knative serving"
        oc delete ingresses.networking.internal.knative.dev --all -n knative-serving || true
        oc delete knativeservings.operator.knative.dev knative-serving -n knative-serving || true
 
        # note, it takes a while to remove the namespace.  Move on to other things before we wait for the removal
        # of this project below
        # oc delete all --all -n knative-serving || true
        oc delete namespace knative-serving --wait=false || true

        remove-operator "amq-streams" || true

        echo "Removing Serverless Operator related CRDs"
        remove-crds "knative.dev" || true
        remove-crds "serverless.openshift.io" || true

        remove-crds "kafka.strimzi.io" || true

        remove-operator "openshift-pipelines-operator-rh" || true

        remove-operator "codeready-workspaces" || true

        remove-crds "checlusters.org.eclipse.che" || true

        # remove gitea related resources
        declare giteaop_prj=gpte-operators
        echo "Removing gitea operator in ${giteaop_prj}"
        oc delete -f $DEMO_HOME/install/gitea/gitea-operator.yaml -n ${giteaop_prj} || true
        # remove CRDs and cluster roles
        oc delete -f $DEMO_HOME/install/gitea/gitea-crd.yaml || true
        oc delete -f $DEMO_HOME/install/gitea/gitea-cluster-role.yaml || true
        oc delete project $giteaop_prj || true

        # actually wait for knative-serving to finish being deleted before we remove the operator
        oc delete namespace knative-serving || true
        remove-operator "serverless-operator" "openshift-serverless" || true

        oc delete namespace "openshift-serverless" || true
    fi

}

main "$@"