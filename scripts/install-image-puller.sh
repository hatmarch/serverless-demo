set -Eeuo pipefail

declare -r SCRIPT_DIR=$(cd -P $(dirname $0) && pwd)

declare TARGET_PROJECT="${1:-codeready}"

# Create project
oc get ns $TARGET_PROJECT 2>/dev/null  || { 
    oc new-project $TARGET_PROJECT
}

echo "Installing Image Puller Subscription"
sed "s/%IM_PRJ%/${TARGET_PROJECT}/g" $DEMO_HOME/install/crw/image-puller-subscription.yaml | oc apply -n $TARGET_PROJECT -f -

# Wait for checluster to be a thing
echo "Waiting for ImagePuller CRDs"
while [ true ] ; do
  if [ -n "$(oc explain KubernetesImagePuller 2>/dev/null)" ] ; then
    break
  fi
  echo -n .
  sleep 3
done
echo "done."

# Update below based on the version of CRW
echo "Creating the Image Puller"
cat <<EOF | oc apply -n $TARGET_PROJECT -f -
apiVersion: che.eclipse.org/v1alpha1
kind: KubernetesImagePuller
metadata:
  name: image-puller
spec:
  configMapName: k8s-image-puller
  daemonsetName: k8s-image-puller
  deploymentName: kubernetes-image-puller
  images: >-
    theia-rhel8=registry.redhat.io/codeready-workspaces/theia-rhel8:2.5;    
    theia-endpoint-rhel8=registry.redhat.io/codeready-workspaces/theia-rhel8:2.5;    
    pluginbroker-metadata-rhel8=registry.redhat.io/codeready-workspaces/pluginbroker-metadata-rhel8:2.5;    
    pluginbroker-artifacts-rhel8=registry.redhat.io/codeready-workspaces/pluginbroker-artifacts-rhel8:2.5;    
    plugin-java8-rhel8=registry.redhat.io/codeready-workspaces/plugin-java8-rhel8:2.5;    
    plugin-java11-rhel8=registry.redhat.io/codeready-workspaces/plugin-java11-rhel8:2.5;    
    stacks-golang-rhel8=registry.redhat.io/codeready-workspaces/stacks-golang-rhel8:2.5;
    maven=quay.io/mhildenb/kn-demo-crw:latest;
EOF
