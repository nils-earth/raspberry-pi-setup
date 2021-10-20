#!/bin/bash

name=blocks
username=nilsweber
http_port=3002
p2p_port=5002

while [[ $# -ge 1 ]]; do
    i="$1"
    case $i in
        -d|--debug)
            name=blocks-debug
            shift
            ;;
        *)
            echo "Unrecognized option $1"
            exit 1
            ;;
    esac
    shift
done

image="$username/$name:latest"
imageIdBefore=$(docker images --format '{{.ID}}' $image)

echo "Pulling latest image - $image"
docker pull $image

if [ $? -ne 0 ]; then
    echo "Pull failed. Are you logged in $(whoami)?"

    if [[ ! -f "~/.docker/config.json" ]]
    then
        docker login || exit 1
        docker pull $image
    else
        exit 1
    fi
fi

imageIdAfter=$(docker images --format '{{.ID}}' $image)

if [ "$imageIdBefore" = "$imageIdAfter" ]; then
  echo "Nothing to do; pull did not result in a new image"
  exit 1
fi

buildVer=$(docker inspect -f '{{ index .Config.Labels "BUILD_VER" }}' $image)
createdOn=$(docker inspect -f '{{ index .Config.Labels "org.opencontainers.image.created" }}' $image)

echo "New image => Id: $imageIdAfter, Build Version $buildVer, Created on: $createdOn"

echo "Stopping and removing existing container"
docker stop $name || true && docker rm $name || true

# For debugging library loading issues add: -e "LD_DEBUG=all"
# http://www.bnikolic.co.uk/blog/linux-ld-debug.html
# Debug dependencies example: ldd /opt/vs/lib/libmmal.so

echo "Starting ngrok on port" ${p2p_port}
./ngrok http ${p2p_port}

echo "Creating new container and starting"
docker run \
    --privileged \
    -e HTTP_PORT=${http_port} \
    -e P2P_PORT=${p2p_port} \
    -p ${http_port}:${http_port} \
    -p ${p2p_port}:${p2p_port} \
    -d \
    --name $name \
    $image

    # --mount type=bind,source=/opt/vc/lib,target=/opt/vc/lib,readonly \
    # --mount type=bind,source=/opt/vc/bin,target=/opt/vc/bin,readonly \

echo "Cleaning up old images"
docker image prune -f

echo "Running. Tailing logs; ctrl+c to stop"
docker logs -f $name