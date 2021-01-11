FROM quay.io/mhildenb/kn-demo-base:latest

USER root

RUN curl -sSL "https://github.com/buildpacks/pack/releases/download/v0.15.1/pack-v0.15.1-linux.tgz" | tar -C /usr/local/bin/ --no-same-owner -xzv pack

USER jboss

# Default DEMO_HOME directory
ENV DEMO_HOME /workspaces/serverless-demo

