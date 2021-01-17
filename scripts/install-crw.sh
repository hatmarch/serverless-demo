set -Eeuo pipefail

declare -r SCRIPT_DIR=$(cd -P $(dirname $0) && pwd)

declare TARGET_PROJECT="${1:-codeready}"

# this is the name of the OpenShift user that will be creating a CRW for the demo
declare DEMO_USERNAME="${2:-opentlc-mgr}"

# the name of a special scc that the workspace service account will need access to in order to create any pods in the 
# workspace devcontainer
declare SPECIAL_WORKSPACE_SCC="${3:-hostmount-anyuid}"

# Create project
oc get ns $TARGET_PROJECT 2>/dev/null  || { 
    oc new-project $TARGET_PROJECT
}

echo "Installing CodeReady Workspace Operator Subscription"
sed "s/%CRW_PRJ%/${TARGET_PROJECT}/g" $DEMO_HOME/install/crw/crw-subscription.yaml | oc apply -n $TARGET_PROJECT -f -

# Wait for checluster to be a thing
echo "Waiting for CheCluster CRDs"
while [ true ] ; do
  if [ -n "$(oc explain checluster 2>/dev/null)" ] ; then
    break
  fi
  echo -n .
  sleep 3
done
echo "done."

echo "Creating the CodeReady Workspace"
cat <<EOF | oc apply -n $TARGET_PROJECT -f -
apiVersion: org.eclipse.che/v1
kind: CheCluster
metadata:
  name: codeready-workspaces
spec:
  server:
    cheFlavor: codeready
    tlsSupport: true
    selfSignedCert: false
    serverMemoryRequest: '2Gi'
    serverMemoryLimit: '6Gi'
  database:
    externalDb: false
    chePostgresHostName: ''
    chePostgresPort: ''
    chePostgresUser: ''
    chePostgresPassword: ''
    chePostgresDb: ''
  auth:
    openShiftoAuth: true
    externalKeycloak: false
    keycloakURL: ''
    keycloakRealm: ''
    keycloakClientId: ''
  storage:
    pvcStrategy: per-workspace
    pvcClaimSize: 1Gi
    preCreateSubPaths: true
    # postgresPVCStorageClassName: ibmc-block-gold
    # workspacePVCStorageClassName: ibmc-block-gold
EOF

# get routing suffix
HOSTNAME_SUFFIX=$(oc whoami --show-server | sed "s#https://api.\([^:]*\):6443#apps.\1#g")
echo "Hostname suffix is ${HOSTNAME_SUFFIX}"

# Wait for che to be up by calling external URL of readiness check
echo "Waiting for Che to come up (at http://codeready-${TARGET_PROJECT}.${HOSTNAME_SUFFIX}/api/system/state/)..."
while [ 1 ]; do
  STAT=$(curl -k -L -s -w '%{http_code}' -o /dev/null http://codeready-${TARGET_PROJECT}.${HOSTNAME_SUFFIX}/api/system/state/)
  if [ "$STAT" = 200 ] ; then
    break
  fi
  echo -n .
  sleep 10
done

if [[ -n "${SPECIAL_WORKSPACE_SCC:-}" ]]; then
  echo "Giving che-workspace service account in ${DEMO_USERNAME}-codeready ${SPECIAL_WORKSPACE_SCC} permissions.  (Assuming demo user is ${DEMO_USERNAME})"
  oc adm policy add-scc-to-user ${SPECIAL_WORKSPACE_SCC} system:serviceaccount:${DEMO_USERNAME}-codeready:che-workspace
fi

# NOTE: Can check using this command:
# oc adm policy who-can use scc ${SPECIAL_WORKSPACE_SCC}

# # Import stack definition
# echo "Getting token"
# FIXME: the user and password are set in the che-identity-secret, at least initially
# USER=admin
# PASSWORD=secret
# SSO_CHE_TOKEN=$(curl -s -d "username=${USER}&password=${PASSWORD}&grant_type=password&client_id=admin-cli" \
#   -X POST https://keycloak-${TARGET_PROJECT}.${HOSTNAME_SUFFIX}/auth/realms/codeready/protocol/openid-connect/token | \
#   jq  -r '.access_token')

# echo "Installing Workspace (${SCRIPT_DIR}/inventory-workspace-maven.json) at: http://codeready-${TARGET_PROJECT}.${HOSTNAME_SUFFIX}/api/stack"
# curl -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' \
#     --header "Authorization: Bearer ${SSO_CHE_TOKEN}" -d @${SCRIPT_DIR}/inventory-workspace-maven.json \
#     "http://codeready-${TARGET_PROJECT}.${HOSTNAME_SUFFIX}/api/workspace/devfile"