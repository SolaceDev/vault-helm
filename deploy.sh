#!/bin/bash
set -eu${DEBUG+x}o pipefail

if (( $# == 0 )); then	
    set -- help	
fi

# All parameters are now passed and environment variables to docker run command in deploy_local.sh
# Check to make sure that all the required variables have been passed:

echo "********************************"
echo "***** params passed to env *****"
echo "command name: $command_name"
echo "CLUSTER_ID: $CLUSTER_ID"
echo "PROJECT_ID: $PROJECT_ID"
echo "REGION: $REGION"
echo "DD_API_KEY: $DD_API_KEY"
echo "********************************"

# Make sure a recognized command was provided.
case $command_name in
  deploy|destroy|validate|help|vault|vaultinit)
    ;;
  *)
    echo "ERROR: Unrecognized deploy.sh command: $command_name"
    echo "valid options are:  deploy|destroy|validate|help|vault|vaultinit"
    echo ""

    exit 1
    ;;
esac


# Verfiy that we have the correct parameters to run the command
# This logic was moved from each function to a common place

if [ "$command_name" == "deploy" ] || "$command_name" == "destroy" ]
then
  if [ -z "$CLUSTER_ID" ] || [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]
    then

        echo "CLUSTER_ID, PROJECT_ID and REGION are required arguments."
        echo "Please re-run the command with the proper arguments set."
        echo ""
        exit 1
    fi
fi

#
# command_help:
#   This function handles running the script actions for the help command.
#
function command_help {
    echo "Runs all of the commands to deploy or destroy a Vault cluster."
    echo ""
    echo "Usage:"
    echo "  ./deploy.sh [ COMMAND [COMMAND_ARGUMENTS...] ]"
    echo ""
    echo "Where:"
    echo "  COMMAND            Is a command to execute.  Currently, the only recognized"
    echo "                     commands are: deploy, destroy, and help.  See below for"
    echo "                     details on each of these commands."
    echo "  COMMAND_ARGUMENTS  The arguments passed along the command.  See the command"
    echo "                     descriptions below for details of the required arguments."
    echo ""
    echo "Commands:"
    echo "  deploy --cluster_id= [ --project_id= [ --region= ] ] --datadog-api-key="
    echo "      The deploy command provisions (or updates) the necessary infrastructure"
    echo "      for a Vault cluster, then installs (or upgrades) the Helm chart for"
    echo "      cert-manager and Vault.  The deploy command provides the glue between all"
    echo "      of these steps."
    echo ""
    echo "      The cluster_id argument is required.  This value is used to uniquely"
    echo "      identify the cluster within the scope of the GCP project."
    echo "      The project_id argument is optional.  If it is omitted, the default value"
    echo "      maas-vault-dev is used, which corresponds to the Vault development GCP"
    echo "      project."
    echo "      The region argument is optional.  If it is omitted, the default value"
    echo "      us-east1 is used."
    echo "      The datadog-api-key is optional.  If it is omitted, the default value"
    echo "      will be pulled from vault.maas-vault-prod.mymaas.net:8200"
    echo ""
    echo "      example:  ./deploy.sh deploy --cluster-id=maas-dev --project_id=maas-gcp --region=us-west-1 \\"
    echo "                --datadog-api-key=8b27de30429e989c22390a8802"
    echo ""
    echo "  destroy --cluster_id= [ --project_id= ]"
    echo "      The destroy command unprovisions all of the infrastructure used by a Vault"
    echo "      cluster."
    echo ""
    echo "      The cluster_id argument is required.  This value is used to uniquely"
    echo "      identify the cluster within the scope of the GCP project."
    echo "      The project_id argument is optional.  If it is omitted, the default value"
    echo "      maas-vault-dev is used, which corresponds to the Vault development GCP"
    echo "      project."
    echo ""
    echo "      example:  ./deploy.sh destroy --cluster-id=maas-dev --project-id=maas-gcp"
    echo ""
    echo "  validate --cluster_id= [ project_id= ]"
    echo "      Validate the Terraform configuration and lint the Helm charts"
    echo "      cluster."
    echo ""
    echo "      example: ./deploy.sh validate --cluster-id=maas-dev --project-id=maas-gcp"
    echo ""
    echo "  help"
    echo "      The help command prints this message and exits."
    echo ""

    exit 0
}

#
# command_destroy:
#   This function handles running the script actions for the destroy command.
#
function command_destroy {

    export TF_VAR_cluster_id=$CLUSTER_ID
    export HELM_cluster_id=$CLUSTER_ID
    export TF_VAR_project_id=$PROJECT_ID

    ./helm/helm.sh --command-name=destroy --HELM_cluster_id=$CLUSTER_ID --HELM_region=$REGION --HELM_project_id=$PROJECT_ID

    ./terraform/terraform.sh destroy
}

#
# command_deploy:
#   This function handles running the script actions for the deploy command.
#
function command_deploy {

    export TF_VAR_cluster_id=$CLUSTER_ID
    export TF_VAR_project_id=$PROJECT_ID
    export TF_VAR_region=$REGION

    ./terraform/terraform.sh apply

    export HELM_cluster_id=$CLUSTER_ID
    export HELM_project_id=$(./terraform/terraform.sh output project_id | tr -d '\r')
    export HELM_lb_address=$(./terraform/terraform.sh output static_ip_address | tr -d '\r')

    ./helm/helm.sh --command-name=deploy --HELM_cluster_id=$HELM_cluster_id --HELM_project_id=$HELM_project_id --HELM_region=$REGION --datadog_api_key=$DD_API_KEY
}

function command_validate {
  export TF_VAR_cluster_id=$CLUSTER_ID
  export HELM_cluster_id=$CLUSTER_ID

  ./terraform/terraform.sh validate
  ./helm/helm.sh --command-name=lint
}

function command_vaultinit {
  export HELM_cluster_id=$CLUSTER_ID
  DEBUG=1

  retries=0
  retry_interval=${2:-5}
  max_retries=${3:-30}

  export VAULT_ADDR="https://${HELM_cluster_id}.${HELM_project_id:-"maas-vault-dev"}.mymaas.net:8200"

  while vault status; [ $? -eq 1 ]; do
    retries=$((retries+1))

    if [[ $retries -ge $max_retries ]]; then
      exit 1
    fi

    sleep $retry_interval
  done

  vault_init_root_token=$(vault operator init -format=yaml | grep root_token | sed 's/.*: //')
  for i in 1 2 3 4 5; do vault login ${vault_init_root_token} && break || sleep 2; done
}

function command_vault {
  export HELM_cluster_id=$CLUSTER_ID
  shift

  export VAULT_ADDR="https://${HELM_cluster_id}.${HELM_project_id:-"maas-vault-dev"}.mymaas.net:8200"

  echo "Running vault $@"
  vault $@
}

# Invoke the appropriate command_... function, based on the value of the
# command_name variable.
command_$command_name "$@"
