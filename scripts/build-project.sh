#!/bin/bash

if [[ -z "$DEMO_HOME" ]]; then
    echo "Must first set DEMO_HOME environment variable before running this script."
fi


BUILD_PROJECTS=( \
    inventory \
    order \
    catalog \
    cart \ 
    coolstore-ui \
)

BUILD_PATHS=( \
    "$DEMO_HOME/inventory-service" \
    "$DEMO_HOME/order-service" \
    "$DEMO_HOME/catalog-service" \
    "$DEMO_HOME/cart-service" \
    "$DEMO_HOME/coolstore-ui" \
)

LOCAL_BUILD_COMMANDS=(
    "mvn clean package -DskipTests"
    "mvn clean package -DskipTests"
    "mvn clean package spring-boot:repackage -DskipTests"
    "mvn clean package -DskipTests"
    "npm install --save-dev nodeshift"
)

REMOTE_BUILD_COMMANDS=(
    "oc start-build inventory --from-file target/*-runner.jar"
    "oc start-build order --from-file target/*-runner.jar"
    "oc start-build catalog --from-file=target/catalog-1.0.0-SNAPSHOT.jar"
    "oc start-build cart --from-file target/*-runner.jar"
    "npm run nodeshift"
)

build_project_local() {
    index=$1
    cd ${BUILD_PATHS[${index}]}
    ${LOCAL_BUILD_COMMANDS[${index}]} &
}

build_project_remote() {
    index=$1
    cd ${BUILD_PATHS[${index}]}
    ${REMOTE_BUILD_COMMANDS[${index}]} &
    # make sure the command starts so that we don't get a race with
    # directory changing
    sleep .5
}

export MAVEN_OPTS="-Xmx1024M -Xss128M -XX:MetaspaceSize=512M -XX:MaxMetaspaceSize=1024M -XX:+CMSClassUnloadingEnabled"

if [ -z $1 ]
then
    count=0
    for i in ${BUILD_PROJECTS[@]}; do
        echo "Building $i"
        build_project_local $count
        count=$count+1
    done

    echo "Waiting for local builds to finish"
    wait
    echo "Local builds completed"
else
   echo "Skipping local builds"
fi

echo "Building remotely"

count=0
for i in ${BUILD_PROJECTS[@]}; do
    echo "Building $i"
    build_project_remote $count
    count=$count+1
done

echo "Waiting for remote builds to finish"
wait
echo "Remote builds completed"
