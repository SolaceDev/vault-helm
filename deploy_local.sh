#!/bin/sh
set -eu${DEBUG+x}o pipefail

# this is the place holder for pulling the dd api key from vault at https://vault.maas-vault-prod.solace.cloud:8200
export VAULT_ADDR=https://vault.maas-vault-prod.solace.cloud:8200
vault_is_setup=0
vault_credentials_used=0

# Set the default project id and region but allow them to be overridden via args
PROJECT_ID="maas-vault-dev"
REGION="us-east1"
enable_datadog=no

# assign arguments to variables
for i in "$@"
do
  case $i in
    -cn=*|--command_name=*)
    command_name="${i#*=}"
    shift
    ;;
    -c=*|--cluster_id=*)
    CLUSTER_ID="${i#*=}"
    shift
    ;;
    -p=*|--project_id=*)
    PROJECT_ID="${i#*=}"
    shift
    ;;
    -r=*|--region=*)
    REGION="${i#*=}"
    shift
    ;;
    -dd|--enable_datadog)
    enable_datadog=yes
    shift
    ;;
    ?*)
    extra_vars="${extra_vars:-""} ${i#*}"
    ;;
  esac
done

# required:  cluster_id, command_name
# optional:  region, project_id (default set above)
# optional:  enable_datadog - if set, either a github token or api/app key are required
if [ -z "$CLUSTER_ID" ] || [ -z "$PROJECT_ID" ] || [ -z "$REGION" ] || [ -z "$command_name" ] 
then
    echo "Error: missing parameter"
    echo ""
    echo "[required] command name: $command_name"
    echo "[required]   CLUSTER_ID: $CLUSTER_ID"
    echo "[optional]   PROJECT_ID: $PROJECT_ID"
    echo "[optional]       REGION: $REGION"
    echo ""
    echo "This command needs to be run with parameters now."
    echo "  Commands are specified as --command_name=<command> or"
    echo "  -cn=<command>"
    echo ""
    echo "*************"
    echo "   to deploy:"
    echo "*************"
    echo ""
    echo "In the deploy scenario, --cluster_id is a required parameter."
    echo "--project_id and --region are set as defaults, but you can override those:"
    echo ""
    echo "./deploy_local.sh --command_name=deploy --cluster_id=vault-${USER} --project_id=maas-vault-dev --region=us-east1"
    echo ""
    echo "To enable the datadog agent, either specify the --enabled_datadog or -dd flag or set the DD_API_KEY and DD_APP_KEY environment variables."
    echo "./deploy_local.sh --command_name=deploy --cluster_id=vault-${USER} --enable_datadog"
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
    exit 1
fi

export CLUSTER_ID
export PROJECT_ID
export REGION

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

# Make sure a recognized command was provided.
case $command_name in
  deploy|destroy|validate|help|vault|vaultinit)
    ;;
  *)
    echo "ERROR: Unrecognized deploy_local.sh command: $command_name"
    echo ""
    echo "valid options are:  deploy, destroy, validate, help, vault, vaultinit"
    echo ""
    exit 1
    ;;
esac

#
# setup_vault:
#   Performs a series of tests to make sure that a Vault server is
#   reachable at $VAULT_ADDR and that a Vault token is available to
#   obtain the necessary secrets.
#
function setup_vault {

  if [ $vault_is_setup == "1" ]; then
    return
  fi

  # Make sure the vault binary is available.
  which vault > /dev/null || ( echo "vault binary not installed" ; exit 1 )

  # Make sure the Vault server is reachable and healthy
  vault status &> /dev/null || ( echo "vault server is not healthy" ; exit 1 )

  # Check if a valid Vault token is present
  if ! vault token lookup &> /dev/null ; then
    echo "Vault token is either invalid or missing. Please complete the vault login below to obtain a token."
    vault login -method=github > /dev/null
  fi

  # Check that the Vault token has the necessary access
  if [ "$(vault token lookup -format=json 2> /dev/null | jq -r '.data.policies[]')" == "default" ]; then
    echo "The GitHub personal access token used for the vault login does not have SSO configured."
    echo "Visit https://github.com/settings/tokens and configure SSO for the token."
    exit 1
  fi

  vault_is_setup=1
}

# Make sure valid GCP credentials are in place
#
# This validation routine will only allow Service Account Key credentials issued
# by the Vault server. If different credentials are needed, set the environment
# variable SKIP_ADC_VALIDATION to 'true' to skip the validation (make sure that
# your alternate credentials are correctly set in the file.)
#
if [ "${SKIP_ADC_VALIDATION:-"false"}" != "true" ] && [ -r "$HOME/.config/gcloud/application_default_credentials.json" ] ; then
  # Found the file that is meant to contain the GCP credentials,

  # Make sure the credentials type is service_account 
  if ! jq -r '.type' "$HOME/.config/gcloud/application_default_credentials.json" | grep -qE 'service_account' ; then
    # The file contains credentials that are not for a Service Account.
    rm -f "$HOME/.config/gcloud/application_default_credentials.json"
  else
    # Make sure the credentials are for the targeted GCP project
    if ! jq -r '.project_id' "$HOME/.config/gcloud/application_default_credentials.json" | grep -qE "$PROJECT_ID" ; then
      # The file contains credentials for the wrong project, so delete it.
      rm -f "$HOME/.config/gcloud/application_default_credentials.json"
    else
      # Make sure the credentials are issued by Vault server
      if ! jq -r '.client_email' "$HOME/.config/gcloud/application_default_credentials.json" | grep -qE '^vaultvault-gcp-clus-[0-9]+@maas-vault-(prod|dev).iam.gserviceaccount.com$' ; then
        # The file contains credentials for a different identity
        rm -f "$HOME/.config/gcloud/application_default_credentials.json"
      else
        # Make sure that the credentials are not expired.
        (
          unset GOOGLE_APPLICATION_CREDENTIALS
          if ! gcloud auth application-default print-access-token &> /dev/null ; then
            # The file does not contain a valid GCP credential, so delete it.
            rm -f "$HOME/.config/gcloud/application_default_credentials.json"
          fi
        )
      fi
    fi
  fi
fi

# Check once more if there isn't a GCP credentials file in place
if [ ! -r "$HOME/.config/gcloud/application_default_credentials.json" ] ; then
  # Attempt to setup Vault token and make sure Vault server is reachable
  if (setup_vault) ; then

    vault_credentials_used=1
    vault_credentials=$(vault read -field=private_key_data gcp/key/vault-gcp-cluster-${PROJECT_ID##"maas-vault-"})
    if [ -n "$vault_credentials" ] ; then
      echo "$vault_credentials" | base64 --decode > ~/.config/gcloud/application_default_credentials.json
    else
      echo "Vault server did not return a Service Account key. Check your Vault token and its associated policies."
      exit 1
    fi
  else
    echo "Vault server not available to obtain dynamic Service Account key"
    echo "Use Google Cloud Console to manually open Service Account key and store it"
    echo "at $HOME/.config/gcloud/application_default_credentials.json"
    exit 1
  fi
fi

if [ "${enable_datadog:-""}" == "yes" ] && [ "$command_name" == "deploy" ] ; then

  if (setup_vault) ; then
    # Default Datadog Vault path suffix
    vault_path_suffix=dev
    if [ "$PROJECT_ID" == "maas-vault-prod" ]; then
      vault_path_suffix=production
    fi

    if [ -z "${DD_API_KEY:-""}" ]; then
      DD_API_KEY=$(vault kv get -field=api-key kv/datadog/$vault_path_suffix)
    fi

    if [ -z "${DD_APP_KEY:-""}" ]; then
      DD_APP_KEY=$(vault kv get -field=app-key kv/datadog/$vault_path_suffix)
    fi
  else
    echo "Vault server not available to obtain DataDog API and APP keys"
    echo "Use DataDog Console to manually open them and set the"
    echo "DD_API_KEY and DD_APP_KEY environment variables with them."
    exit 1
  fi
  # ensure that the keys were not empty
  test -n $DD_API_KEY -a -n $DD_APP_KEY
fi

export DD_API_KEY
export DD_APP_KEY
export enable_datadog

image_tag=${VAULT_INSTALLER_IMAGE_TAG:-"$(id -un)-vault:latest"}
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
    -e CLUSTER_ID \
    -e PROJECT_ID \
    -e REGION \
    -e DD_API_KEY \
    -e DD_APP_KEY \
    -e enable_datadog \
    -e command_name="$command_name" \
    "${image_tag}" \
    "${extra_vars:-""}"

