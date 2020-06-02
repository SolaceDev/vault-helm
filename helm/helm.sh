#!/bin/bash
set -e${DEBUG+x}o pipefail

# Make sure to switch the current directory to the one where this script is located.
cd "$( dirname "${BASH_SOURCE[0]}" )"

for i in "$@"
do
  case $i in
    -command_name=*|--command-name=*)
    command_name="${i#*=}"
    shift
    ;;
    -HELM_cluster_id=*|--HELM_cluster_id=*)
    HELM_cluster_id="${i#*=}"
    shift
    ;;
    -HELM_region=*|--HELM_region=*)
    HELM_region="${i#*=}"
    shift
    ;;
    -HELM_project_id=*|--HELM_project_id=*)
    HELM_project_id="${i#*=}"
    shift
    ;;
    -datadog_api_key=*|--datadog_api_key=*)
    DD_API_KEY="${i#*=}"
    shift
    ;;
  esac
done

if [ -z "$HELM_cluster_id" ] || [ -z "$HELM_project_id" ] || [ -z "$HELM_region" ] || [ -z "$command_name" ]
then
    echo "helm.sh error:"
    echo ""
    echo "command_name, HELM_cluster_id, HELM_project_id and HELM_region are required arguments."
    echo "One or more of those values not found:"
    echo ""
    echo "command name: $command_name"
    echo "CLUSTER_ID: $HELM_cluster_id"
    echo "PROJECT_ID: $HELM_project_id"
    echo "REGION: $HELM_region"
    echo ""
      
    exit 1
fi

export HELM_cluster_id

cluster_issuer_name=${HELM_CLUSTER_ISSUER_NAME:-"letsencrypt"}
cluster_issuer_server=${HELM_CLUSTER_ISSUER_SERVER:-"https://acme-v02.api.letsencrypt.org/directory"}

gcloud auth activate-service-account --key-file=${HOME}/.config/gcloud/application_default_credentials.json

#
# command_help:
#   Handles the case where this script is invoked with the help command.
#
function command_help {
    echo "Deploys or removes the Helm releases and Kubernetes resources needed"
    echo "in a Vault cluster."
    echo ""
    echo "Usage:"
    echo "  ./helm.sh --command-name="
    echo ""
    echo "Where:"
    echo "  --command-name=    Is a command to execute.  Currently, the only recognized"
    echo "                     commands are: deploy, destroy, help and lint.  See below for"
    echo "                     details on each of these commands."
    echo ""
    echo "Commands:"
    echo "  --command-name=deploy"
    echo "      The deploy command installs the necessary Helm releases and Kubernetes"
    echo "      resources for a Vault cluster."
    echo ""
    echo "  --command-name=destroy"
    echo "      The destroy command unprovisions all of the Kubernetes resources used by a Vault"
    echo "      cluster."
    echo ""
    echo " --command-name=lint"
    echo "      This command runs:  helm lint -f maas-values.yaml ./vault-helm"
    echo ""
    echo "  help"
    echo "      The help command prints this message and exits."
    echo ""
    echo "Environment Variables:"
    echo "  This script requires the following environment variables to be set."
    echo "  You can also pass them into helm.sh as a parameter with: "
    echo "  --HELM_cluster_id=vault-dev --HELM_project_id=vault0 --HELM_region=us-east-1"
    echo ""
    echo "  HELM_cluster_id     The unique name of the Vault cluster.  This value is used as"
    echo "                      the Kubernetes namespace name.  This variable is needed for the"
    echo "                      deploy and destroy commands."
    echo "  HELM_project_id     The GCP project ID of the Vault cluster."
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
    gcloud container clusters get-credentials ${HELM_cluster_id} --region ${HELM_region} --project ${HELM_project_id}

    # Elevating privilege to avoid permissions errors when creating RBACs.
    if ! kubectl get clusterrolebindings/cluster-admin-binding ; then
        kubectl create clusterrolebinding cluster-admin-binding \
                --clusterrole=cluster-admin \
                --user=$(gcloud config get-value core/account)
    fi

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

    # Add the helm kubernetes repo
    # Currently required for datago-7454: datadog vault implementation - stable/datadog
    helm repo add stable https://kubernetes-charts.storage.googleapis.com

    # Make sure Helm repos are up to date.
    helm repo update

    # Run the appropriate Helm command
    helm $(get_helm_command_for_release "cert-manager" "cert-manager") "cert-manager" "jetstack/cert-manager" --namespace "cert-manager" --version 0.14.1

    # Keep checking to see if the cert-manager-webhook deployment is ready, if not sleep for 1 second and repeat.
    while ! kubectl get deployments/cert-manager-webhook --namespace cert-manager | grep '1/1' > /dev/null ; do
        sleep 1
    done

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

    echo "deploying datadog..."

    # need to set the namespace because helm v3 thinks it's smart
    # be aware that we'll need to switch back if we do anything else
    kubectl config set-context $HELM_cluster_id

    # after everything is up and running we will deploy datadog via helm v3 (this will not work in helm v2)
    helm $(get_helm_command_for_release "$HELM_cluster_id" "datadog") -f datadog-values.yaml --set datadog.apiKey=$DD_API_KEY stable/datadog --set targetSystem=linux --version 2.3.6
}

#
# command_destroy:
#   Handles the case where this script is invoked with the destroy command.
#
function command_destroy {
    gcloud container clusters get-credentials ${HELM_cluster_id} --region ${HELM_region} --project ${HELM_project_id}

    # Remove the Vault Helm release
    helm uninstall "vault" --namespace $HELM_cluster_id || true

    # Remove the vault-certificate Certificate resource
    kubectl delete certificates/vault-certificate --namespace $HELM_cluster_id || true

    # Remove the cluster_id namespace
    kubectl delete namespaces/$HELM_cluster_id || true

    # Remove the letsencrypt ClusterIssuer
    kubectl delete clusterissuers/$cluster_issuer_name || true

    # Remove the cert-manager Helm release
    helm uninstall "cert-manager" --namespace cert-manager || true

    # Remove the cert-manager namespace
    kubectl delete namespaces/cert-manager || true

    # Remove the cluster-admin-binding
    kubectl delete clusterrolebindings/cluster-admin-binding || true
}

function command_lint {
    helm lint -f maas-values.yaml ./vault-helm
}

command_$command_name "$@"