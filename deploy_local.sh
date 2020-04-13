#!/bin/bash
set -eu${DEBUG+x}o pipefail

base_image_tag=${USER}-vault-base:latest
image_tag=${USER}-vault:latest

(cd baseimage && docker build . -t ${base_image_tag})
docker build . --build-arg BASE_IMAGE=${base_image_tag} -t ${image_tag}

# rw of gcloud config required for kubectl configuration
docker run -it --rm -v $HOME/.config/gcloud:/root/.config/gcloud:rw ${image_tag} $@