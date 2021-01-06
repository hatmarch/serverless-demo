#!/bin/bash

set -Eeuo pipefail

declare -r SCRIPT_DIR=$(cd -P $(dirname $0) && pwd)
declare PROJECT_PREFIX="kn-demo"

display_usage() {
cat << EOF
$0: Create Serverless Demo --

  Usage: ${0##*/} [ OPTIONS ]
  
    -i         [optional] Install prerequisites
    -p <TEXT>  [optional] Project prefix to use.  Defaults to "kn-demo"
    -s         [optional] Skip installation of the Serverless Operator (to allow it being done manually)

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
  while getopts ':ip:h' option; do
      case "${option}" in
          i  ) prereq_flag=true;;
          s  ) skipserverless_flag=true;;
          p  ) p_flag=true; PROJECT_PREFIX="${OPTARG}";;
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
}

main() {
    # import common functions
    . $SCRIPT_DIR/common-func.sh

    trap 'error' ERR
    trap 'cleanup' EXIT SIGTERM
    trap 'interrupt' SIGINT

    get_and_validate_options "$@"

    #
    # create the cicd project
    #
    cicd_prj="${PROJECT_PREFIX}-cicd"
    oc get ns $cicd_prj 2>/dev/null  || { 
        oc new-project $cicd_prj
    }

    #create the dev project if it doesn't already exist
    dev_prj="${PROJECT_PREFIX}-dev"
    oc get ns $dev_prj 2>/dev/null  || { 
        oc new-project $dev_prj
    }

    echo "Initiatlizing git repository in gitea and configuring webhooks"
    oc apply -f $DEMO_HOME/install/gitea/gitea-server-cr.yaml -n $cicd_prj
    # we'll check back on gitea in a moment.  We'll do some other setup whilst waiting
 
    # Install pre-reqs before tekton
    if [[ -n "${prereq_flag:-}" ]]; then
        if [[ -n "${skipserverless_flag:-}" ]]; then
            echo "Installing pre-requisites with kafka in ${dev_prj} and NO Serverless"
            # FIXME: Add support to suppress serverless installation 
            ${SCRIPT_DIR}/install-prereq.sh --skip-serverless ${dev_prj}
        else
            echo "Installing pre-requisites with kafka in ${dev_prj}"
            ${SCRIPT_DIR}/install-prereq.sh ${dev_prj}
        fi
    else
        echo "Skipping pre-requisite installation"
    fi

    echo "Installing CodeReady Workspaces"
    ${SCRIPT_DIR}/install-crw.sh codeready

    # 
    # Install Tekton resources
    #
    echo "Installing Tekton supporting resources"

    echo "Installing PVCs"
    oc apply -n $cicd_prj -R -f $DEMO_HOME/install/tekton/volumes

    echo "Installing Tasks (in $cicd_prj and $dev_prj)"
    oc apply -n $cicd_prj -R -f $DEMO_HOME/install/tekton/tasks
    oc apply -n $dev_prj -f $DEMO_HOME/install/tekton/tasks/oc-client-local-task.yaml

    echo "Installing tokenized pipeline"
    sed "s/demo-dev/${dev_prj}/g" $DEMO_HOME/install/tekton/pipelines/payment-pipeline.yaml | sed "s/demo-support/${dev_prj}/g" | oc apply -n $cicd_prj -f -

    echo "Installing Tekton Triggers"
    sed "s/demo-dev/${dev_prj}/g" $DEMO_HOME/install/tekton/triggers/triggertemplate.yaml | oc apply -n $cicd_prj -f -
    oc apply -n $cicd_prj -f $DEMO_HOME/install/tekton/triggers/gogs-triggerbinding.yaml
    oc apply -n $cicd_prj -f $DEMO_HOME/install/tekton/triggers/eventlistener-gogs.yaml

    # There can be a race when the system is installing the pipeline operator in the $cicd_prj
    echo -n "Waiting for Pipelines Operator to be installed in $cicd_prj..."
    while [[ "$(oc get $(oc get csv -oname -n $cicd_prj| grep pipelines) -o jsonpath='{.status.phase}' -n $cicd_prj 2>/dev/null)" != "Succeeded" ]]; do
        echo -n "."
        sleep 1
    done

    # Allow the pipeline service account to push images into the dev account
    oc policy add-role-to-user -n $dev_prj system:image-pusher system:serviceaccount:$cicd_prj:pipeline
    
    # Add a cluster role that allows fined grained access to knative resources without granting edit
    oc apply -f $DEMO_HOME/install/tekton/roles/kn-deployer-role.yaml
    # ..and assign the pipeline service account that role in the dev project
    oc adm policy add-cluster-role-to-user -n $dev_prj kn-deployer system:serviceaccount:$cicd_prj:pipeline

    # Seeding the .m2 cache
    echo "Seeding the .m2 cache"
    oc apply -n $cicd_prj -f $DEMO_HOME/install/tekton/init/copy-to-workspace-task.yaml 
    oc create -n $cicd_prj -f $DEMO_HOME/install/tekton/init/seed-cache-task-run.yaml
    # This should cause everything to block and show output
    tkn tr logs -L -f -n $cicd_prj 

    # Wait for gitea rollout to finish before finishing initialization with Tekton
    oc wait --for=condition=Running Gitea/gitea-server -n $cicd_prj --timeout=6m
    echo -n "Waiting for gitea deployment to appear..."
    while [[ -z "$(oc get deploy gitea -n $cicd_prj 2>/dev/null)" ]]; do
        echo -n "."
        sleep 1
    done
    echo "done!"
    oc rollout status deploy/gitea -n $cicd_prj

    echo "Initializing gitea"
    oc create -f $DEMO_HOME/install/gitea/gitea-init-taskrun.yaml -n $cicd_prj
    # output the logs of the latest task
    tkn tr logs -L -f -n $cicd_prj

    echo "Install configmaps"
    sed "s/demo-support/${dev_prj}/g" $DEMO_HOME/install/config/configmap-coolstore-topics-cfg.yaml | oc apply -n $dev_prj -f -

    echo "Installing coolstore website (minus payment)"
    oc process -f $DEMO_HOME/install/templates/cool-store-no-payment-template.yaml -p PROJECT=$dev_prj | oc apply -f - -n $dev_prj

    # FIXME: This should not be necessary based on recent changes to the template
    # echo "Correcting routes"
    # oc project $dev_prj
    # $DEMO_HOME/scripts/route-fix.sh

    echo "updating all images"
    # Fix up all image streams by pointing to pre-built images (which should trigger deployments)
    $DEMO_HOME/scripts/image-stream-setup.sh

    echo "Demo installation completed without error."
}

main "$@"