#!/bin/sh
set -e${DEBUG+x}o pipefail

# Set the default project id and region but allow them to be overridden via args
PROJECT_ID="maas-vault-dev"
REGION="us-east1"

for i in "$@"
do
  case $i in
    -command_name=*|--command_name=*)
    command_name="${i#*=}"
    shift
    ;;
    -cluster_id=*|--cluster_id=*)
    CLUSTER_ID="${i#*=}"
    shift
    ;;
    -project_id=*|--project_id=*)
    PROJECT_ID="${i#*=}"
    shift
    ;;
    -region=*|--region=*)
    REGION="${i#*=}"
    shift
    ;;
    -datadog_api_key=*|--datadog_api_key=*)
    DD_API_KEY="${i#*=}"
    shift
    ;;
  esac
done

if [ -z "$CLUSTER_ID" ] || [ -z "$PROJECT_ID" ] || [ -z "$REGION" ] || [ -z "$command_name" ]
then
    echo "deploy_local.sh error:"
    echo ""
    echo "command name: $command_name"
    echo "  CLUSTER_ID: $CLUSTER_ID"
    echo "  PROJECT_ID: $PROJECT_ID"
    echo "      REGION: $REGION"
    echo ""
    echo "This command needs to be run with parameters now.  Commands are specified as --command_name=<command>"
    echo ""
    echo "*************"
    echo "   to deploy:"
    echo "*************"
    echo ""
    echo "In the deploy scenario, --cluster_id and --datadog_api_key are required parameters."
    echo "--project_id and --region are set as defaults, but you can override those:"
    echo ""
    echo "./deploy_local.sh --command_name=deploy --cluster_id=vault-${USER} --project_id=maas-vault-dev --region=us-east1 --datadog_api_key=abcde123456789"
    echo ""
    echo "*************"
    echo "  to destroy:"
    echo "*************"
    echo ""
    echo "In the destroy scenario, --cluster_id is required."
    echo "--project_id and --region are set as defaults, but can be overridden:"
    echo ""
    echo "./deploy_local.sh --command_name=destroy --cluster_id=vault-${USER}"
    echo ""
    echo ""
    exit 1
fi

# Make sure a recognized command was provided.
case $command_name in
  deploy|destroy|validate|help|vault|vaultinit)
    ;;
  *)
    echo "ERROR: Unrecognized deploy_local.sh command: $command_name"
    echo ""
    echo "valid options are:  deploy|destroy|validate|help|vault|vaultinit"
    echo ""
    exit 1
    ;;
esac

if [ "$command_name" == "deploy" ] && [ -z "$DD_API_KEY" ]; then
  echo "The datadog api key was not provided."
  echo "default dd api key unset, quitting"
  exit 1
  
  # this is the place holder for pulling the dd api key from vault at https://vault.maas-vault-prod.mymaas.net:8200
  # export VAULT_ADDR=https://vault.maas-vault-prod.mymaas.net:8200
  # gcloud auth login
  # local GITHUB_TOKEN=$(vault read -field=github_token github/dev/github_token | base64 -D)
  # vault login -method=github token=${GITHUB_TOKEN}
  # DD_API_KEY=$(vault read -field=datadog_api_key datadog/dev/api_key | base64 -D)
fi

image_tag=${VAULT_INSTALLER_IMAGE_TAG:-$(id -un)-vault:latest}
docker_args=${VAULT_INSTALLER_DOCKER_ARGS:-"-it -v $HOME/.config/gcloud:/root/.config/gcloud:rw"}

if [[ -z ${VAULT_INSTALLER_BASE_IMAGE_TAG:-} ]]; then
  base_image_tag=$(id -un)-vault-base:latest
  (cd baseimage && docker build . -q -t ${base_image_tag})
else
  base_image_tag="${VAULT_INSTALLER_BASE_IMAGE_TAG}"
fi

echo "building docker container from Dockerfile"
docker build . -q --build-arg BASE_IMAGE=${base_image_tag} -t ${image_tag}

# rw of gcloud config required for kubectl configuration
echo "here's what we're running: "
echo "docker run --rm ${docker_args} -e command_name=$command_name -e CLUSTER_ID=$CLUSTER_ID -e PROJECT_ID=$PROJECT_ID -e REGION=$REGION -e DD_API_KEY=$DD_API_KEY ${image_tag}"
docker run --rm ${docker_args} -e command_name=$command_name -e CLUSTER_ID=$CLUSTER_ID -e PROJECT_ID=$PROJECT_ID -e REGION=$REGION -e DD_API_KEY=$DD_API_KEY ${image_tag}