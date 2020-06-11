#!/bin/bash
set -e${DEBUG+x}o pipefail

if [[ $# == 0 ]]; then
    set -- help
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
    echo ""
    echo "--command_name=deploy --cluster_id= [ --project_id= [ --region= ] ] --datadog_api_key="
    echo ""
    echo "      The deploy command provisions (or updates) the necessary infrastructure"
    echo "      for a Vault cluster, then installs (or upgrades) the Helm chart for"
    echo "      cert-manager and Vault.  This command provides the glue between all"
    echo "      of these steps."
    echo ""
    echo "      The cluster_id argument is required.  This value is used to uniquely"
    echo "      identify the cluster within the scope of the GCP project."
    echo ""
    echo "      The project_id argument is optional.  If it is omitted, the default value"
    echo "      maas-vault-dev is used, which corresponds to the Vault development GCP"
    echo "      project."
    echo ""
    echo "      The region argument is optional.  If it is omitted, the default value"
    echo "      us-east1 is used."
    echo ""
    echo "      The datadog-api-key is optional.  If it is omitted, the default value"
    echo "      will be pulled from vault.maas-vault-prod.mymaas.net:8200"
    echo ""
    echo "      example:  ./deploy.sh --command_name=deploy --cluster_id=maas-dev --project_id=maas-vault-dev --region=us-east1 \\"
    echo "                --datadog-api-key=abcde1234556677889 --datadog-app-key=zzxxxccv1234556677889"
    echo ""
    echo "--command_name=destroy --cluster_id= [ --project_id= ]"
    echo "      The destroy command unprovisions all of the infrastructure used by a Vault"
    echo "      cluster."
    echo ""
    echo "      The cluster_id argument is required.  This value is used to uniquely"
    echo "      identify the cluster within the scope of the GCP project."
    echo "      The project_id argument is optional.  If it is omitted, the default value"
    echo "      maas-vault-dev is used, which corresponds to the Vault development GCP"
    echo "      project."
    echo ""
    echo "      example:  ./deploy.sh --command_name=destroy --cluster_id=maas-dev --project_id=maas-gcp"
    echo ""
    echo "--command_name=validate --cluster_id= [ project_id= ]"
    echo "      Validate the Terraform configuration and lint the Helm charts"
    echo "      cluster."
    echo ""
    echo "      example: ./deploy.sh --command_name=validate --cluster_id=maas-dev --project_id=maas-gcp"
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

  if [ -z "$CLUSTER_ID" ]; then
    echo "deploy.sh error:"
    echo "cluster_id was not provided."
    echo "Please run your command again:"
    echo ""
    echo "./deploy_local.sh --command_name=destroy --cluster-id=mycluster"
    exit 1
  fi
  if [ -z "$REGION" ]; then
    echo "Region was not provided; using the default of us-east1"
    REGION="us-east1"
  fi
  if [ -z "$PROJECT_ID" ]; then
    echo "project_id was not provided; using the default of maas-vault-dev"
    PROJECT_ID="maas-vault-dev"
  fi

  
  export TF_VAR_cluster_id=$CLUSTER_ID
  export HELM_cluster_id=$CLUSTER_ID
  export TF_VAR_project_id=$PROJECT_ID

  ./helm/helm.sh --command_name=destroy --HELM_cluster_id=$CLUSTER_ID --HELM_region=$REGION --HELM_project_id=$PROJECT_ID

  ./terraform/terraform.sh destroy
}

#
# command_deploy:
#   This function handles running the script actions for the deploy command.
#
function command_deploy {

# All parameters are now passed and environment variables to docker run command in deploy_local.sh
# Check to make sure that all the required variables have been passed:

if [ -z "$CLUSTER_ID" ] || [ -z "$PROJECT_ID" ] || [ -z "$REGION" ] || [ -z "$command_name" ] || [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ] || [[ $enable_datadog == "yes" && -z "$DD_CLUSTER_AGENT_AUTH_TOKEN" ]]
  then
      echo "deploy.sh error:"
      echo ""
      echo "command_name, CLUSTER_ID, PROJECT_ID, REGION and DD_API_KEY are required arguments."
      echo "Please re-run the command with the proper arguments set:"
      echo ""
      echo "command name: $command_name"
      echo "CLUSTER_ID: $CLUSTER_ID"
      echo "PROJECT_ID: $PROJECT_ID"
      echo "REGION: $REGION"
      echo ""
      exit 1
fi

    export TF_VAR_cluster_id=$CLUSTER_ID
    export TF_VAR_project_id=$PROJECT_ID
    export TF_VAR_region=$REGION

    ./terraform/terraform.sh apply

    export HELM_cluster_id=$CLUSTER_ID
    export HELM_project_id=$(./terraform/terraform.sh output project_id | tr -d '\r')
    export HELM_lb_address=$(./terraform/terraform.sh output static_ip_address | tr -d '\r')

    ./helm/helm.sh --command_name=deploy --HELM_cluster_id=$HELM_cluster_id --HELM_project_id=$HELM_project_id --HELM_region=$REGION --datadog_api_key=$DD_API_KEY --datadog_app_key=$DD_APP_KEY --datadog_cluster_key=$DD_CLUSTER_AGENT_AUTH_TOKEN --enable_datadog=$enable_datadog
}

function command_validate {

  if [ -z "$REGION" ]; then
    echo "Region was not provided; using the default of us-east1"
    REGION="us-east1"
  fi
  if [ -z "$PROJECT_ID" ]; then
    echo "project_id was not provided; using the default of maas-vault-dev"
    PROJECT_ID="maas-vault-dev"
  fi

  export TF_VAR_cluster_id=$CLUSTER_ID
  export HELM_cluster_id=$CLUSTER_ID

  ./terraform/terraform.sh validate
  ./helm/helm.sh --command_name=lint --HELM_cluster_id=$CLUSTER_ID --HELM_project_id=$PROJECT_ID --HELM_region=$REGION 
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
