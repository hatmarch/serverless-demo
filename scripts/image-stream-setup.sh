#!/bin/bash
oc tag --source docker mhildema/cart:v1 cart:initial-build
oc tag --source docker mhildema/coolstore-ui:v1 coolstore-ui:initial-build
oc tag --source docker mhildema/inventory:v1 inventory:initial-build
oc tag --source docker mhildema/catalog:v1 catalog:initial-build
oc tag --source docker mhildema/order:v1 order:initial-build

# Seems that some time needs to pass otherwise openshift will think the tag doesn't point to an image and then the 
# tagging of latest will fail (which in turn will cause deployment to fail)
sleep 5

# Now trigger Deployments by setting the latest tag in the image stream (which the DeploymentConfigs should be keyed to)
oc tag cart:initial-build cart:latest
oc tag coolstore-ui:initial-build coolstore-ui:latest
oc tag inventory:initial-build inventory:latest
oc tag catalog:initial-build catalog:latest
oc tag order:initial-build order:latest

