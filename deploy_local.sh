#!/bin/sh
set -eu${DEBUG+x}o pipefail

# Set the default project id and region but allow them to be overridden via args
PROJECT_ID=maas-vault-dev
REGION=us-east-1

while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -cluster_id=*|--cluster_id=*)
            CLUSTER_ID=$VALUE
            ;;
        -project_id=*|--project_id=*)
            PROJECT_ID=$VALUE
            ;;
        -region=*|--region=*)
            REGION=$VALUE
            ;;
        -datadog_api_key=*|--datadog_api_key=*)
            DD_API_KEY=$VALUE
            ;;
    esac
    shift
done

echo "CLUSTER_ID: $CLUSTER_ID"
echo "PROJECT_ID: $PROJECT_ID"
echo "REGION: $REGION"
echo "DD_API_KEY: $DD_API_KEY"

image_tag=${VAULT_INSTALLER_IMAGE_TAG:-$(id -un)-vault:latest}
docker_args=${VAULT_INSTALLER_DOCKER_ARGS:-"-it -v $HOME/.config/gcloud:/root/.config/gcloud:rw"}

if [[ -z ${VAULT_INSTALLER_BASE_IMAGE_TAG:-} ]]; then
  base_image_tag=$(id -un)-vault-base:latest
  (cd baseimage && docker build . -q -t ${base_image_tag})
else
  base_image_tag="${VAULT_INSTALLER_BASE_IMAGE_TAG}"
fi

docker build . -q --build-arg BASE_IMAGE=${base_image_tag} -t ${image_tag}

# rw of gcloud config required for kubectl configuration
echo "here's what we're running: "
echo "docker run --rm ${docker_args} ${image_tag} $@"
docker run --rm ${docker_args} -e CLUSTER_ID=$CLUSTER_ID -e PROJECT_ID=$PROJECT_ID -e REGION=$REGION -e DD_API_KEY=$DD_API_KEY ${image_tag}
