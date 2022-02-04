#!/bin/sh
set -eu${DEBUG+x}o pipefail

# this is the place holder for pulling the dd api key from vault at https://vault.maas-vault-prod.solace.cloud:8200
export VAULT_ADDR=https://vault.maas-vault-prod.solace.cloud:8200

# Set the default project id and region but allow them to be overridden via args
PROJECT_ID="maas-vault-dev"
REGION="us-east1"

# assign arguments to variables
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
    -datadog_app_key=*|--datadog_app_key=*)
    DD_APP_KEY="${i#*=}"
    shift
    ;;
    -github_token=*|--github_token=*)
    GITHUB_TOKEN="${i#*=}"
    shift
    ;;
    -enable_datadog=*|--enable_datadog=*)
    enable_datadog="${i#*=}"
    shift
    ;;
    ?*)
    extra_vars="${extra_vars:-""} ${i#*}"
    ;;
  esac
done

#
# Check if environment variable CI is NOT SET and the PROJECT_ID is set to
# maas-vault-prod, to trigger the warning banner and additional prompt.
#
if [ "${CI+x}" != "x" ] && [ "${PROJECT_ID:-}" == "maas-vault-prod" ] ; then
  echo ""
  echo "[95mPPPPP   RRRRR    OOOO   DDDDD [0m"
  echo "[35mP    P  R    R  O    O  D    D[0m"
  echo "[34mP    P  R    R  O    O  D    D[0m"
  echo "[32mP    P  R    R  O    O  D    D[0m"
  echo "[92mPPPPP   RRRRR   O    O  D    D[0m"
  echo "[93mP       R  R    O    O  D    D[0m"
  echo "[33mP       R   R   O    O  D    D[0m"
  echo "[31mP       R    R   OOOO   DDDDD [0m"
  echo ""
  echo "Are you sure you want to deploy to production?"
  read -p "Enter 'prod' to confirm: " answer

  if [ "${answer}" != "prod" ]; then
    echo "Aborted"
    exit 0
  fi
fi

# required:  cluster_id, command_name
# optional:  region, project_id (default set above)
# optional:  enable_datadog - if set, either a github token or api/app key are required
if [ -z "$CLUSTER_ID" ] || [ -z "$PROJECT_ID" ] || [ -z "$REGION" ] || [ -z "$command_name" ] 
then
    echo "deploy_local.sh error:"
    echo ""
    echo "[required] command name: $command_name"
    echo "[required]   CLUSTER_ID: $CLUSTER_ID"
    echo "[optional]   PROJECT_ID: $PROJECT_ID"
    echo "[optional]       REGION: $REGION"
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
    echo "./deploy_local.sh --command_name=deploy --cluster_id=vault-${USER} --project_id=maas-vault-dev --region=us-east1 --datadog_api_key=abcde123456789 --datadog_app_key=zxvblkj9876543 --enable_datadog=yes"
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

if [[ "${enable_datadog:-""}" == "yes" ]]
then
  # Main feature flag for enable/disable datadog
  echo "*****************************"
  echo "datadog has been enabled."
  echo "*****************************"

  # test for inclusion of dd keys
  if [ "$command_name" == "deploy" ] && ([ -z "${DD_API_KEY:-""}" ] || [ -z "${DD_APP_KEY:-""}" ])
  then
    echo "you have enabled datadog but no datadog api or app keys have been provided.  We will attempt to get from vault..."
    echo ""
    if [[ -z $GITHUB_TOKEN ]]
    then
      echo "You have not provided datadog keys or a github token."
      echo "if you don't provide keys, you must provide a github token which has access to $VAULT_ADDR"
      echo ""
      echo "please run the command again with --github_token=<your token>"
      exit 1
    fi   

    # set the vault path for the kv
    vault_path="kv/datadog/dev"

    # log into vault to grab the keys
    echo "logging into vault to check for keys at $vault_path"
    echo ""
    vault login -method=github token=${GITHUB_TOKEN}
    echo ""

    # retrieve the keys from vault
    DD_API_KEY=$(vault kv get -field=api-key $vault_path)
    DD_APP_KEY=$(vault kv get -field=app-key $vault_path)

    echo "retrieved DD_API_KEY: $DD_API_KEY"
    echo "retrieved DD_APP_KEY: $DD_APP_KEY"
    echo ""
    
    # ensure that the keys were not empty
    if [[ -z $DD_API_KEY || -z $DD_APP_KEY ]]
    then
      echo "Retrieved key was blank for APP or API!"
      echo "please check vault to ensure the values exist in: $vault_path"
      exit 1
    fi
  fi
  else
    echo "*****************************"
    echo "datadog is disabled."
    echo "to enable, run with:"
    echo "--enable-datadog=yes"
    echo "*****************************"
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
docker run \
    --rm \
    ${docker_args} \
    -e HELM_UPGRADE_FORCE \
    -e HELM_DRY_RUN \
    -e DEBUG \
    -e CLUSTER_ID="$CLUSTER_ID" \
    -e PROJECT_ID="$PROJECT_ID" \
    -e REGION="$REGION" \
    -e DD_API_KEY="${DD_API_KEY:-""}" \
    -e DD_APP_KEY="${DD_APP_KEY:-""}" \
    -e enable_datadog="${enable_datadog:-""}" \
    -e command_name="$command_name" \
    "${image_tag}" \
    "${extra_vars:-""}"
