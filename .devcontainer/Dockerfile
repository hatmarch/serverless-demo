FROM quay.io/mhildenb/serverless-demo-base:1.0

USER root

# install stern
RUN cd /usr/local/bin && \
    wget https://github.com/wercker/stern/releases/download/1.11.0/stern_linux_amd64 && \
    mv stern_linux_amd64 stern && chmod 755 stern && \
# instal knative client
    wget -qO- https://mirror.openshift.com/pub/openshift-v4/clients/serverless/0.13.1/kn-linux-amd64-0.13.1.tar.gz | tar -zxvf - -C /usr/local/bin ./kn && chmod 755 /usr/local/bin/kn && \
# instal hey
    wget https://storage.googleapis.com/hey-release/hey_linux_amd64 && \
    mv hey_linux_amd64 hey && chmod 755 hey && \
# install istioctl
    curl -L https://github.com/istio/istio/releases/download/1.4.0/istioctl-1.4.0-linux.tar.gz | tar -zxvf - -C /usr/local/bin && chmod 755 /usr/local/bin/istioctl

# install AWS cli
RUN curl "https://d1vvhvl2y92vvt.cloudfront.net/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm awscliv2.zip && rm -rf ./aws 
    # && ln -s /usr/local/bin/aws2 /usr/local/bin/aws

# for htpasswd support
RUN yum install -y httpd-tools-2.4.37-16.module+el8.1.0+4134+e6bad0ed.x86_64

USER jboss