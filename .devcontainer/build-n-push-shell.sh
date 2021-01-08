#!/bin/bash

set -Eeuo pipefail

declare -r SCRIPT_DIR=$(cd -P $(dirname $0) && pwd)

declare SHELL_TAG=${1:-latest}

$SCRIPT_DIR/build-n-push-common.sh kn-demo-shell $SHELL_TAG 