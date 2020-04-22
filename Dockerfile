# syntax = docker/dockerfile:1.0-experimental

#
# This is the base dockerfile to be used with the BUILDKIT to build the 
# image that the .devcontainer docker image is based on
# 
FROM quay.io/mhildenb/cloudnative-workspaces-quarkus:1.0

USER root

# command line for this would look something like
# docker build --progress=plain --secret id=myuser,src=docker-secrets/myuser.txt --secret id=mypass,src=docker-secrets/mypass.txt -t quay.io/mhildenb/comparison-demo-base:1.0 .
RUN --mount=type=secret,id=myuser --mount=type=secret,id=mypass \
    subscription-manager register --username=$(cat /run/secrets/myuser) \
    --password=$(cat /run/secrets/mypass) --auto-attach

RUN dnf clean all && rm -r /var/cache/dnf  && dnf upgrade -y --allowerasing --nobest --skip-broken && \
    dnf update -y --allowerasing --nobest --skip-broken

# prerequisites for the eb command line
RUN yum group install -y "Development Tools" && \
     yum install -y zlib-devel openssl-devel ncurses-devel libffi-devel sqlite-devel.x86_64 readline-devel.x86_64 \
     bzip2-devel.x86_64

# install skopeo
RUN dnf install -y skopeo

RUN subscription-manager unregister
