#!/bin/sh
set -eu${DEBUG+x}o pipefail

docker_args=${VAULT_INSTALLER_DOCKER_ARGS:-"-it -v $HOME/.config/gcloud:/root/.config/gcloud:rw"}
image_tag=$(id -un)-vault:latest

if [[ -z ${VAULT_INSTALLER_BASE_IMAGE_TAG:-} ]]; then
  base_image_tag=$(id -un)-vault-base:latest
  (cd baseimage && docker build . -t ${base_image_tag})
else
  base_image_tag="${VAULT_INSTALLER_BASE_IMAGE_TAG}"
fi

docker build . --build-arg BASE_IMAGE=${base_image_tag} -t ${image_tag}

# rw of gcloud config required for kubectl configuration
docker run --rm ${docker_args} ${image_tag} $@
