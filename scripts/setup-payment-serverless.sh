#!/bin/bash

set -e -u -o pipefail

# Install a local image of the builder that we'll use for the payment service
#oc import-image openjdk18-openshift:1.5 --from=registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift:1.5 --confirm
#oc new-build openjdk18-openshift:1.5 --binary --name=payment

# Setup a binary based build for our quarkus instance
oc new-build  --image-stream="openshift/redhat-openjdk18-openshift:1.5" --binary --name=payment    

# build our local payment service
ORIG_DIR=$(pwd -P)
cd $DEMO_HOME/payment-service
mvn package -DskipTests

# upload our payment jar that we compiled.
# NOTE: Must first compile the payment 
oc start-build payment --from-file target/payment-1.0-SNAPSHOT*.jar --follow

cd $ORIG_DIR

# Setup a S2I based build for our native quarkus instance
# oc new-build quay.io/quarkus/ubi-quarkus-native-s2i:19.3.1-java11~https://github.com/hatmarch/serverless-demo.git --context-dir=payment-service --name=payment-native-old
oc new-build quay.io/quarkus/ubi-quarkus-native-s2i:19.2.0~https://github.com/hatmarch/serverless-demo.git --context-dir=payment-service --name=payment-native \
    -e MAVEN_OPTS=" -Xmx1024M -Xss128M -XX:MetaspaceSize=512M -XX:MaxMetaspaceSize=1024M -XX:+CMSClassUnloadingEnabled"

oc cancel-build bc/payment-native
oc patch bc/payment-native -p '{"spec":{"resources":{"limits":{"cpu":"4", "memory":"6Gi"}}}}'
oc start-build bc/payment-native --follow

# if building locally
oc new-build quay.io/quarkus/ubi-quarkus-native-binary-s2i:19.2.0 --name payment-native --binary

# Tag the created images
oc tag payment:latest payment:initial
oc tag payment-native:latest payment:initial-native

kn service create payment --image image-registry.openshift-image-registry.svc:5000/$PROJECT/payment:initial-native --revision-name "{{.Service}}-{{.Generation}}" --concurrency-limit=2
kn service update payment --image image-registry.openshift-image-registry.svc:5000/$PROJECT/payment:initial --revision-name "{{.Service}}-{{.Generation}}" --concurrency-limit=2

# split traffic 50/50 between the two revisions
kn service update payment --traffic payment-1=50,payment-2=50

# see payment.http for examples of using hey

# # add a revision using the payment-native:initial image 
# kn service update payment --image image-registry.openshift-image-registry.svc:5000/user1-cloudnativeapps/payment-native:initial --revision-name "{{.Service}}-{{.Generation}}"

# # Move 100% of traffic to revision called payment-4 and 0% to payment-``
# kn service update payment --traffic payment-4=100,payment-1=0

# # update concurrency limit (creates another revision)
# kn service update payment --concurrency-limit=2

# # Move 100% of traffic to the latest revision
# kn service update payment --traffic @latest=100

# # install an initial version of the payment service
# oc apply -f $DEMO_HOME/install/payment-alone.yaml

# # this line is to enable debugging (just in case)
# oc set env dc/payment JAVA_OPTIONS="-Xdebug -Xrunjdwp:transport=dt_socket,address=5000,server=y,suspend=n"

# # import image into our local image stream
# oc import-image payment:initial-build --from mhildema/payment:v1

# # this should trigger a deployment
# oc tag payment:initial-build payment:latest

# oc expose svc/payment

# oc rollout status -w dc/payment

# # example sending messages (from here: https://kafka.apache.org/quickstart#quickstart_send)
# echo '{"orderId": "12321","total": "232.23", "creditCard": {"number":"4232454678667866","expiration": "04/22","nameOnCard": "Jane G Doe"}, "billingAddress": "123 Anystreet, Pueblo, CO 32213", "name": "Jane Doe"}' | oc exec -i -c kafka my-cluster-kafka-0 -n user1-cloudnativeapps -- /opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic orders

# # example receiving messages (from previous)
# oc exec -c kafka my-cluster-kafka-0 -n user1-cloudnativeapps -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic orders --from-beginning
# oc exec -c kafka my-cluster-kafka-0 -n user1-cloudnativeapps -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic payments --from-beginning
