# FROM registry.redhat.io/codeready-workspaces/stacks-java-rhel8
FROM quay.io/openshiftlabs/cloudnative-workspaces-quarkus:1.3

USER root

# install stern
RUN cd /usr/local/bin && \
    wget https://github.com/wercker/stern/releases/download/1.6.0/stern_linux_amd64 && \
    mv stern_linux_amd64 stern && chmod 755 stern && \
# instal knative client
    wget -qO- https://mirror.openshift.com/pub/openshift-v4/clients/serverless/latest/kn-linux-amd64-0.9.0.tar.gz | tar zxvf - -C /usr/local/bin && \
# instal hey
    wget https://storage.googleapis.com/hey-release/hey_linux_amd64 && \
    mv hey_linux_amd64 hey && chmod 755 hey

USER jboss