#!/bin/sh
set -eu${DEBUG+x}o pipefail

# Set the default project id and region but allow them to be overridden via args
PROJECT_ID=maas-vault-dev
REGION=us-east1

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
      echo "command_name, CLUSTER_ID, PROJECT_ID and REGION are required arguments."
      echo "Please re-run the command with the proper arguments set:"
      echo ""
      echo "./deploy_local.sh --command-name=deploy --cluster_id=vault-dev --project_id=maas-vault-dev --region=us-east-1"
      echo ""
      echo "(project_id and region are set by default, so you only really need command_name and cluster_id)"
      echo ""
      
      exit 1
fi

# Make sure a recognized command was provided.
case $command_name in
  deploy|destroy|validate|help|vault|vaultinit)
    ;;
  *)
    echo "ERROR: Unrecognized deploy_local.sh command: $command_name"
    echo "valid options are:  deploy|destroy|validate|help|vault|vaultinit"
    echo ""

    exit 1
    ;;
esac

if [ -z "$DD_API_KEY" ]; then
  echo "The datadog api key was not provided."
  echo "We will be using the default DD API KEY."
  echo "default dd api key unset, quitting"
  exit 1
  
  # this is the place holder for pulling the dd api key from vault at https://vault.maas-vault-prod.mymaas.net:8200
  # export VAULT_ADDR=https://vault.maas-vault-prod.mymaas.net:8200
  # gcloud auth login
  # GITHUB_TOKEN=$(vault read -field=github_token github/dev/github_token | base64 -D)
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
echo "docker run --rm ${docker_args} -e CLUSTER_ID=$CLUSTER_ID -e PROJECT_ID=$PROJECT_ID -e REGION=$REGION -e DD_API_KEY=$DD_API_KEY ${image_tag}"
docker run --rm ${docker_args} -e command_name=$command_name -e CLUSTER_ID=$CLUSTER_ID -e PROJECT_ID=$PROJECT_ID -e REGION=$REGION -e DD_API_KEY=$DD_API_KEY ${image_tag} $@
