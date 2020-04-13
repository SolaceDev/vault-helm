#!/bin/bash
set -eu${DEBUG+x}o pipefail

# Make sure to switch the current directory to the one where this script is located.
cd "$( dirname "${BASH_SOURCE[0]}" )"

if [[ $# == 0 ]]; then
    set -- help
fi

command_name=$1
shift

while [[ -z ${HELM_cluster_id:-} ]]; do
    echo "No Vault Cluster ID specified."
    read -p "Specify the Vault cluster ID: " HELM_cluster_id
done

export HELM_cluster_id

cluster_issuer_name=${HELM_CLUSTER_ISSUER_NAME:-"letsencrypt"}
cluster_issuer_server=${HELM_CLUSTER_ISSUER_SERVER:-"https://acme-v02.api.letsencrypt.org/directory"}

#
# command_help:
#   Handles the case where this script is invoked with the help command.
#
function command_help {
    echo "Deploys or removes the Helm releases and Kubernetes resources needed"
    echo "in a Vault cluster."
    echo ""
    echo "Usage:"
    echo "  ./helm.sh [ COMMAND ]"
    echo ""
    echo "Where:"
    echo "  COMMAND            Is a command to execute.  Currently, the only recognized"
    echo "                     commands are: deploy, destroy, and help.  See below for"
    echo "                     details on each of these commands."
    echo ""
    echo "Commands:"
    echo "  deploy"
    echo "      The deploy command installs the necessary Helm releases and Kubernetes"
    echo "      resources for a Vault cluster."
    echo ""
    echo "  destroy"
    echo "      The destroy command unprovisions all of the Kubernetes resources used by a Vault"
    echo "      cluster."
    echo ""
    echo "  help"
    echo "      The help command prints this message and exits."
    echo "Environment Variables:"
    echo "  This script requires the following environment variables to be set. If they are"
    echo "  missing, the script will prompt for a value."
    echo ""
    echo "  HELM_cluster_id     The unique name of the Vault cluster.  This value is used as"
    echo "                      the Kubernetes namespace name.  This variable is needed for the"
    echo "                      deploy and destroy commands."
    echo "  HELM_project_id     The GCP project ID of the Vault cluster.  This variable is only"
    echo "                      needed for the deploy command."
    echo "  HELM_lb_address     The IP address created and reserved for the Vault cluster's"
    echo "                      load balancer.  This variable is only needed for the deploy"
    echo "                      command."
    echo ""

    exit 0
}

#
# create_namespace_if_missing:
#   Checks if the specified Kubernetes namespace exists, and if not, creates
#   it.
#
function create_namespace_if_missing {
    local namespace=$1

    if ! kubectl describe namespaces/$namespace > /dev/null 2>&1; then
        kubectl create namespace $namespace
    fi
}

#
# get_helm_command_for_release:
#   Determines which Helm command should be used: upgrade or install, depending
#   on whether the specified Helm release exists already or not.
#
function get_helm_command_for_release {
    local namespace=$1
    local release_name=$2

    if [[ -z $(helm list --namespace $namespace --short --filter $release_name) ]]; then
        echo "install"
    else
        echo "upgrade"
    fi
}

#
# command_deploy:
#   Handles the case where this script is invoked with the deploy command.
#
function command_deploy {
    # The deploy command needs 2 additional environment variables to be set.
    while [[ -z $HELM_project_id ]]; do
        echo "No GCP Project ID specified."
        read -p "Specify the GCP Project ID: " HELM_project_id
    done

    while [[ -z $HELM_lb_address ]]; do
        echo "No Load Balancer Address specified."
        read -p "Specify the Load Balancer Address: " HELM_lb_address
    done

    export HELM_project_id
    export HELM_lb_address

    # Install the cert-manager CRDs
    kubectl apply \
            --validate=false \
            -f https://github.com/jetstack/cert-manager/releases/download/v0.14.1/cert-manager-legacy.crds.yaml

    # Create the cert-manager namespace if it doesn't exist
    create_namespace_if_missing "cert-manager"

    # Add the jetstack/cert-manager repo
    helm repo add jetstack https://charts.jetstack.io

    # Make sure Helm repos are up to date.
    helm repo update

    # Run the appropriate Helm command
    helm $(get_helm_command_for_release "cert-manager" "cert-manager") "cert-manager" "jetstack/cert-manager" --namespace "cert-manager" --version 0.14.1

    # Create a ClusterIssuer resource
    echo "apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: ${cluster_issuer_name}
spec:
  acme:
    # certificates, and issues related to your account.
    email: nobody@solace.com
    server: ${cluster_issuer_server}
    privateKeySecretRef:
      name: solace-issuer-account-key
    solvers:
    - dns01:
        clouddns:
            project: ${HELM_project_id}" | kubectl apply -f -

    # Create the Vault cluster namespace if it doesn't exist
    create_namespace_if_missing $HELM_cluster_id

    echo "apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: vault-certificate
  namespace: ${HELM_cluster_id}
spec:
  secretName: vault-server-tls
  issuerRef:
    kind: ClusterIssuer
    name: ${cluster_issuer_name}
  commonName: ${HELM_cluster_id}.${HELM_project_id}.mymaas.net
  dnsNames:
  - ${HELM_cluster_id}.${HELM_project_id}.mymaas.net" | kubectl apply -f -

    # Run the appropriate Helm command for the Vault release
    helm $(get_helm_command_for_release "$HELM_cluster_id" "vault") \
            vault ./vault-helm \
            --namespace $HELM_cluster_id \
            --values ./maas-values.yaml \
            --set maas.gcpProject=$HELM_project_id \
            --set maas.lbAddress=$HELM_lb_address \
            --set maas.kmsProject=$HELM_project_id \
            --set maas.kmsKeyRing=$HELM_project_id \
            --set maas.kmsCryptoKey=${HELM_project_id}-unseal \
            --set maas.bucketName=${HELM_project_id}-${HELM_cluster_id}-data

}

#
# command_destroy:
#   Handles the case where this script is invoked with the destroy command.
#
function command_destroy {
    # Remove the Vault Helm release
    helm uninstall "vault" --namespace $HELM_cluster_id || true

    # Remove the vault-certificate Certificate resource
    kubectl delete certificates/vault-certificate --namespace $HELM_cluster_id || true

    # Remove the letsencrypt ClusterIssuer
    kubectl delete clusterissuers/$cluster_issuer_name || true

    # Remove the cert-manager Helm release
    helm uninstall "cert-manager" --namespace cert-manager || true
}

command_$command_name "$@"