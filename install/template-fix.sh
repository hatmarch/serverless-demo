#!/bin/bash

SCRIPT_DIR=$(dirname $0)

#
# Fix up all the hardcoded routes
#
for app in $(oc get route --no-headers | awk '{ print $1 }'); do
    echo "app is $app"
    oc delete route $app
    oc expose svc $app
done