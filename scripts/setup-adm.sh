#!/bin/bash

set -e -u -o pipefail

# Setup non-kube admin user for http password
NEW_ADMIN=$1
PASS=$2

# Name of the file and data aspect of the secret
FILENAME="htpasswd"

# Look up the configuration file to find the name of the secret for OAuth
SECRET_NAME=$(oc get OAuth/cluster -o jsonpath='{.spec.identityProviders[0].htpasswd.fileData.name}')

# download the existing secret to updated htpasswd
oc get secret $SECRET_NAME -n openshift-config -o jsonpath="{.data.$FILENAME}" | base64 --decode > $FILENAME

# add to it with desired user
htpasswd -Bb $FILENAME $NEW_ADMIN "$PASS"

# replace the secret
oc create secret generic $SECRET_NAME --from-file=htpasswd --dry-run -o yaml | oc replace -f - -n openshift-config

# remote temporary file
rm $FILENAME

# make the new user/identity a cluster admin
oc adm policy add-cluster-role-to-user cluster-admin $NEW_ADMIN
