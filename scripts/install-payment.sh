#!/bin/bash

set -e -u -o pipefail

# Install a local image of the builder that we'll use for the payment service
oc import-image openjdk18-openshift:1.5 --from=registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift:1.5 --confirm

# install an initial version of the payment service
oc apply -f $DEMO_HOME/install/payment-alone.yaml

# this line is to enable debugging (just in case)
oc set env dc/payment JAVA_OPTIONS="-Xdebug -Xrunjdwp:transport=dt_socket,address=5000,server=y,suspend=n"

# import image into our local image stream
oc import-image payment:initial-build --from mhildema/payment:v1

# this should trigger a deployment
oc tag payment:initial-build payment:latest

oc expose svc/payment

oc rollout status -w dc/payment

# # example sending messages (from here: https://kafka.apache.org/quickstart#quickstart_send)
# echo '{"orderId": "12321","total": "232.23", "creditCard": {"number":"4232454678667866","expiration": "04/22","nameOnCard": "Jane G Doe"}, "billingAddress": "123 Anystreet, Pueblo, CO 32213", "name": "Jane Doe"}' | oc exec -i -c kafka my-cluster-kafka-0 -n user1-cloudnativeapps -- /opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic orders

# echo '{"orderId":"order-1919-id-0.17061231920733744","paymentId":"27369","remarks":"Payment of 31.2325 succeeded for Joe Bloggs CC details: {\"number\":\"41234123412341234\",\"expiration\":\"12/20\",\"nameOnCard\":\"Joe Bloggs\"}","status":"COMPLETED (Quarkus Local)"}' | oc exec -i -c kafka my-cluster-kafka-0 -n coolstore -- /opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic payments

# # example receiving messages (from previous)
# oc exec -c kafka my-cluster-kafka-0 -n user1-cloudnativeapps -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic orders --from-beginning
# oc exec -c kafka my-cluster-kafka-0 -n user1-cloudnativeapps -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic payments --from-beginning
