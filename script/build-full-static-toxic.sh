#!/bin/sh

set -eux

CONTAINER=toxic-static-build

docker build -t toxchat/toxic:latest -f script/Dockerfile .
docker rm "$CONTAINER" || true  # delete leftover container 
docker run --name "$CONTAINER" --detach toxchat/toxic:latest
docker cp "$CONTAINER:/app/toxic" "$PWD/toxic-static"
docker rm "$CONTAINER"
