#!/bin/bash
set -eu${DEBUG+x}o pipefail

# If there are no command line arguments, add 'help'
if (( $# == 0 )); then
    set -- help
fi

# Take the first command line argument as the value for the command_name
# variable.
command_name=$1
shift

# Make sure a recognized command was provided.
case $command_name in
  deploy|destroy|help)
    ;;
  *)
    echo "ERROR: Unrecognized deploy.sh command: $command_name"

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
    echo "  deploy cluster_id [ project_id [ region ] ]"
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
    echo ""
    echo "  destroy cluster_id [ project_id ]"
    echo "      The destroy command unprovisions all of the infrastructure used by a Vault"
    echo "      cluster."
    echo ""
    echo "      The cluster_id argument is required.  This value is used to uniquely"
    echo "      identify the cluster within the scope of the GCP project."
    echo "      The project_id argument is optional.  If it is omitted, the default value"
    echo "      maas-vault-dev is used, which corresponds to the Vault development GCP"
    echo "      project."
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
    if (( $# == 0 )); then
        echo "ERROR: The cluster_id argument is missing."

        exit 1
    fi

    export TF_VAR_cluster_id=$1

    if (( $# == 2 )); then
        export TF_VAR_project_id=$2
    fi

    ./terraform/terraform.sh destroy
}

#
# command_deploy:
#   This function handles running the script actions for the deploy command.
#
function command_deploy {
    if (( $# == 0 )); then
        echo "ERROR: The cluster_id argument is missing."

        exit 1
    fi

    export TF_VAR_cluster_id=$1

    if (( $# == 2 )); then
        export TF_VAR_project_id=$2

        if (( $# == 3 )); then
            export TF_VAR_region=$3
        fi
    fi

    ./terraform/terraform.sh apply

    helm_project_id=$(./terraform/terraform.sh output project_id | tr -d '\r')
    helm_static_address=$(./terraform/terraform.sh output static_ip_address | tr -d '\r')

    gcloud container clusters get-credentials ${TF_VAR_cluster_id} --region ${TF_VAR_region:-"us-east1"} --project ${TF_VAR_project_id:-"maas-vault-dev"}

    # Install the cert-manager CRDs
    kubectl apply \
            --validate=false \
            -f https://github.com/jetstack/cert-manager/releases/download/v0.14.1/cert-manager-legacy.crds.yaml

    namespace_cert_manager=cert-manager

    # Create a namespace for cert-manager if it doesn't already exist
    if ! kubectl describe namespaces/$namespace_cert_manager > /dev/null 2>&1; then
        kubectl create namespace $namespace_cert_manager
    fi

    # Make sure the jetstack Helm repo exists.
    helm repo add jetstack https://charts.jetstack.io

    # Update the local cache of Helm repos.
    helm repo update

    # Install or upgrade the helm release for cert-manager
    if [[ -z $(helm list --namespace ${namespace_cert_manager} --short --filter cert-manager) ]]; then
        helm install cert-manager jetstack/cert-manager --namespace $namespace_cert_manager --version 0.14.1
    else
        helm upgrade cert-manager jetstack/cert-manager --namespace $namespace_cert_manager --version 0.14.1
    fi

    # Create a namespace for Vault if it doesn't already exist
    if ! kubectl describe namespaces/$TF_VAR_cluster_id > /dev/null 2>&1; then
        kubectl create namespace $TF_VAR_cluster_id
    fi


    # Install or upgrade the helm release for Vault
    if [[ -z $(helm list --namespace ${TF_VAR_cluster_id} --short --filter vault) ]]; then
        helm_command=install
    else
        helm_command=upgrade
    fi

    helm $helm_command \
            vault ./helm/vault-helm \
            --namespace $TF_VAR_cluster_id \
            --values ./helm/maas-values.yaml \
            --set maas.gcpProject=$helm_project_id \
            --set maas.lbAddress=$helm_static_address \
            --set maas.kmsProject=$helm_project_id \
            --set maas.kmsKeyRing=$helm_project_id \
            --set maas.kmsCryptoKey=${helm_project_id}-unseal \
            --set maas.bucketName=${helm_project_id}-${TF_VAR_cluster_id}-data
}

# Invoke the appropriate command_... function, based on the value of the
# command_name variable.
command_$command_name "$@"
