#!/bin/bash

# ====== Garbage collection of obsolete Docker images ====== #

set -e

# get a list of dangling images
DANGLING_IMAGES="$(docker images --filter "dangling=true" --no-trunc -q)"

# check to see if there are any danging images to remove
if [ ! -z "${DANGLING_IMAGES}" ]
then
  echo "Removing dangling images:"
  docker rmi ${DANGLING_IMAGES}
else
  echo "No dangling images to remove"
fi

# compare the images in use to images on the system to get a list of images to remove
IMAGES_TO_REMOVE="$(comm -13 <(docker inspect -f '{{ .Image }}' $(docker ps -qa) | sort -u) <(docker images -aq --no-trunc | sort -u))"

# check to see if there are any images to remove
if [ ! -z "${IMAGES_TO_REMOVE}" ]
then
  echo "Removing unused images:"
  # we use '-f' here as we compare the actual image IDs to see if that ID is in use.  this is required to be able to remove multiple tags of an image that isn't used
  docker rmi -f ${IMAGES_TO_REMOVE}
else
  echo "No unused images to remove"
fi