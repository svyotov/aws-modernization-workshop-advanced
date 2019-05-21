#!/bin/bash

DOCKER_LOGIN=`aws ecr get-login --no-include-email`
PASSWORD=`echo $DOCKER_LOGIN | cut -d' ' -f6`
IMAGE_URI=$1
DOCKER_USER=AWS DOCKER_PASSWORD=${PASSWORD} CLAIR_ADDR=52.42.3.7:6060 ./klar $IMAGE_URI
