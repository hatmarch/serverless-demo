#!/bin/bash

set -Eeuo pipefail

declare -r SCRIPT_DIR=$(cd -P $(dirname $0) && pwd)

# echo "SCRIPT_DIR is $SCRIPT_DIR"

declare REGISTRY="quay.io"
declare GROUP="mhildenb"
declare CONTAINER_IMAGE="homemade-serverless-java"
declare IMAGE_TAG="initial-service-1.0"
declare REGISTRY_USERNAME="$GROUP"
declare REGISTRY_PASSWORD=""

display_usage() {
cat << EOF
$0: Create Payment Service --

  Create a new image container image using quarkus containers and jib

  Usage: ${0##*/} [ OPTIONS ]
  
    -r <TEXT>  [optional] Name of the registry.  Defaults to $REGISTRY
    -g <TEXT>  [optional] Name of the group.  Defaults to $GROUP
    -c <TEXT>  [optional] Container Image name.  Defaults to $CONTAINER_IMAGE
    -t <TEXT>  [optional] Tag for container image.  Defaults to $IMAGE_TAG
    -p <TEXT>  [optional] Password to access registry
    -u <TEXT>  [optional] User for the registry.  Defaults to $REGISTRY_USERNAME

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
  while getopts ':p:r:g:c:t:u:h' option; do
      case "${option}" in
          r  ) reg_flag=true; REGISTRY="${OPTARG}";;
          g  ) group_flag=true; GROUP="${OPTARG}";;
          c  ) container_flag=true; CONTAINER_IMAGE="{OPTARG}";;
          t  ) tag_flag=true; IMAGE_TAG=${OPTARG};;
          u  ) user_flag=true; REGISTRY_USERNAME=${OPTARG};;
          p  ) password_flag=true; REGISTRY_PASSWORD="${OPTARG}";;
          h  ) display_usage; exit;;
          \? ) printf "%s\n\n" "  Invalid option: -${OPTARG}" >&2; display_usage >&2; exit 1;;
          :  ) printf "%s\n\n%s\n\n\n" "  Option -${OPTARG} requires an argument." >&2; display_usage >&2; exit 1;;
      esac
  done
  shift "$((OPTIND - 1))"

  if [[ -z ${password_flag:-} && -z "${REGISTRY_USERNAME}" ]]; then
      printf '%s\n\n' 'ERROR - username must not be null when password provided' >&2
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

    cd $DEMO_HOME/coolstore/payment-service

    MAVEN_CMD=$(cat <<EOF
mvn -B package -DskipTests -Dquarkus.container-image.build=true \
        -Dquarkus.container-image.push=true \
        -Dquarkus.jib.base-jvm-image=gcr.io/distroless/java:11 \
        -Dquarkus.container-image.registry=${REGISTRY} \
        -Dquarkus.container-image.group=${GROUP} \
        -Dquarkus.container-image.name=${CONTAINER_IMAGE} \
        -Dquarkus.container-image.tag=${IMAGE_TAG}
EOF
)
    echo "MAVEN_CMD is $MAVEN_CMD"

    if [[ -n ${password_flag:-} ]]; then
        MAVEN_CMD="$MAVEN_CMD -Dquarkus.container-image.username=$REGISTRY_USERNAME -Dquarkus.container-image.password=\"$REGISTRY_PASSWORD\""
    fi

    echo "MAVEN_CMD is $MAVEN_CMD"

    eval $MAVEN_CMD
}

main "$@"