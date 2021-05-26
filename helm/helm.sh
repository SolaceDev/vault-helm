#!/bin/bash
set -eu${DEBUG+x}o pipefail

# Make sure to switch the current directory to the one where this script is located.
cd "$( dirname "${BASH_SOURCE[0]}" )"

if [[ $# == 0 ]]; then
    set -- help
fi

for i in "$@"
do
  case $i in
    -command_name=*|--command_name=*)
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
    -datadog_app_key=*|--datadog_app_key=*)
    DD_APP_KEY="${i#*=}"
    shift
    ;;
    -enable_datadog=*|--enable_datadog=*)
    enable_datadog="${i#*=}"
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
    echo "Re-run the command with proper arguments:"
    echo ""
    echo "./helm/helm.sh --command_name=<command> --HELM_cluster_id=<HELM_cluster_id> --HELM_project_id=<HELM_project_id> --HELM_region=<REGION>"
    echo ""
    echo "This script is normally called via deploy.sh and is not normally called directly from the command line."
    echo ""

    exit 1
fi

export HELM_cluster_id

cluster_issuer_name=${HELM_CLUSTER_ISSUER_NAME:-"letsencrypt"}

# You can set HELM_CLUSTER_ISSUER_SERVER to a custom value here
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
    echo "  ./helm.sh --command_name="
    echo ""
    echo "Where:"
    echo "  --command_name=    Is a command to execute.  Currently, the only recognized"
    echo "                     commands are: deploy, destroy, help and lint.  See below for"
    echo "                     details on each of these commands."
    echo ""
    echo "Commands:"
    echo "  --command_name=deploy"
    echo "      The deploy command installs the necessary Helm releases and Kubernetes"
    echo "      resources for a Vault cluster."
    echo ""
    echo "  --command_name=destroy"
    echo "      The destroy command unprovisions all of the Kubernetes resources used by a Vault"
    echo "      cluster."
    echo ""
    echo " --command_name=lint"
    echo "      This command runs:  helm lint -f maas-values.yaml ./vault-helm"
    echo ""
    echo "  help"
    echo "      The help command prints this message and exits."
    echo ""
    echo "Environment Variables:"
    echo "  This script requires the following environment variables to be set."
    echo ""
    echo "  You can also pass them into helm.sh as a parameter with: "
    echo "  --HELM_cluster_id=vault-dev --HELM_project_id=maas-vault-dev --HELM_region=us-east-1"
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

    if [[ ${HELM_project_id} == "maas-vault-prod" ]]; then
        CERT_MANAGER_SUFFIX=-legacy
    fi

    # Install the cert-manager CRDs
    kubectl apply \
            --validate=false \
            -f https://github.com/jetstack/cert-manager/releases/download/v0.14.1/cert-manager${CERT_MANAGER_SUFFIX:-}.crds.yaml

    # Create the cert-manager namespace if it doesn't exist
    create_namespace_if_missing "cert-manager"

    # Add the jetstack/cert-manager repo
    helm repo add jetstack https://charts.jetstack.io

    # Add the helm kubernetes repo
    # Currently required for datago-7454: datadog vault implementation - stable/datadog
    helm repo add stable https://charts.helm.sh/stable

    # Make sure Helm repos are up to date.
    helm repo update

    # Run the appropriate Helm command
    helm $(get_helm_command_for_release "cert-manager" "cert-manager") "cert-manager" "jetstack/cert-manager" --namespace "cert-manager" --version 0.15.1

    # Keep checking to see if the cert-manager-webhook deployment is ready, if not sleep for 1 second and repeat.
    while ! kubectl get deployments/cert-manager-webhook --namespace cert-manager | grep '1/1' > /dev/null ; do
        sleep 1
    done

    certificate_dns_name=${HELM_cluster_id}.${HELM_project_id}.mymaas.net
    if [[ ${HELM_project_id} == "maas-vault-prod" ]]; then
        certificate_dns_name=${HELM_cluster_id}.maas-vault-prod.solace.cloud
    fi

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
            project: ${HELM_project_id}" | kubectl apply --validate=false -f -

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
  commonName: ${certificate_dns_name}
  dnsNames:
  - ${certificate_dns_name}" | kubectl apply --validate=false -f -

    echo " $(get_helm_command_for_release "$HELM_cluster_id" "vault") vault"
    # Create a datadog seceret in $HELM_cluster_id for audit log shipment to datadog -
    # Datadog agent is running as a sidecar in the vault continer
    if [[ -z $(kubectl get secrets --namespace  $HELM_cluster_id | grep datadog-vault-secret) ]]
    then
        echo "Creating a secret for sidecar container for vault..."
        kubectl create secret generic datadog-vault-secret \
                           --from-literal api-key=$DD_API_KEY \
                           --namespace  $HELM_cluster_id
    else
        echo "Secret for datadgo sidecar container for vault already exists."
    fi
    # Run the appropriate Helm command for the Vault release
    helm $(get_helm_command_for_release "$HELM_cluster_id" "vault") \
            vault ./vault-helm \
            --namespace $HELM_cluster_id \
            --values ./maas-values.yaml \
            --values ./upgrade.yaml \
            --set maas.gcpProject=$HELM_project_id \
            --set maas.lbAddress=$HELM_lb_address \
            --set maas.kmsProject=$HELM_project_id \
            --set maas.kmsKeyRing=$HELM_project_id \
            --set maas.kmsCryptoKey=${HELM_project_id}-unseal \
            --set maas.bucketName=${HELM_project_id}-${HELM_cluster_id}-data

    echo "creating namespace datadog, if it does not exist..."
    # create a separate namespace to run datadog in
    create_namespace_if_missing datadog

    # put the dd_api_key and dd_app_key into k8s secrets (if they don't exist)
    if [[ -z $(kubectl get secrets --all-namespaces | grep datadog-secret) ]]
    then
        echo "datadog-agent does not exist, creating secret"
        kubectl create secret generic datadog-secret --from-literal api-key=$DD_API_KEY --from-literal app-key=$DD_APP_KEY --namespace datadog
    else
        echo "datadog-agent secret found."
    fi
    echo "*******************************"
    echo "enable_datadog: $enable_datadog"
    echo "*******************************"

    # logic to handle the datadog-agent upgrade process
    if [[ $(get_helm_command_for_release "datadog" "datadog-agent") == "install" && $enable_datadog == "yes" ]]
    then
        echo "installing datadog..."
        # deploy datadog via helm v3
        helm install --namespace "datadog" --values ./datadog/datadog-values.yaml \
            datadog-agent \
            --set datadog.apiKey=datadog-secret \
            --set maas.clusterFQDN=${certificate_dns_name} \
            --set kube-state-metrics.image.tag=v1.8.0 \
            --set kube-state-metrics.collectors.mutatingwebhookconfigurations=false \
            --set kube-state-metrics.collectors.volumeattachments=false \
            --set kube-state-metrics.collectors.validatingwebhookconfigurations=false \
            --set kube-state-metrics.collectors.networkpolicies=false \
            --set kube-state-metrics.collectors.verticalpodautoscalers=false \
            stable/datadog --set targetSystem=linux
            echo "datadog installed"
    elif [[ $(get_helm_command_for_release "datadog" "datadog") == "upgrade" && $enable_datadog == "yes" ]]
    then
        echo "upgrading datadog..."
        # upgrade datadog via helm
        helm upgrade --install --namespace "datadog" --values ./upgrade.yaml --values ./datadog/datadog-values.yaml \
            datadog-agent \
            --set datadog.apiKeyExistingSecret=datadog-secret \
            --set maas.clusterFQDN=${certificate_dns_name} \
            --set kube-state-metrics.image.tag=v1.8.0 \
            --set kube-state-metrics.collectors.mutatingwebhookconfigurations=false \
            --set kube-state-metrics.collectors.validatingwebhookconfigurations=false \
            --set kube-state-metrics.collectors.networkpolicies=false \
            --set kube-state-metrics.collectors.volumeattachments=false \
            --set kube-state-metrics.collectors.verticalpodautoscalers=false \
            stable/datadog --set targetSystem=linux
            echo "datadog upgraded"
    else
        echo "command: $(get_helm_command_for_release "datadog" "datadog-agent") not initialized for helm datadog.  We will do nothing in this case."
    fi

      # logic for the datadog-cluster-agent
    if [[ $(get_helm_command_for_release "datadog" "datadog-cluster-agent") == "install" && $enable_datadog == "yes" ]]
    then
        echo "installing datadog-cluster-agent"
        helm install --namespace "datadog" --values ./datadog/datadog-values.yaml \
            datadog-cluster-agent \
            --set datadog.apiKey=datadog-secret \
            --set datadog.appKey=datadog-secret \
            --set maas.clusterFQDN=${certificate_dns_name} \
            --set kube-state-metrics.image.tag=v1.8.0 \
            --set kube-state-metrics.collectors.mutatingwebhookconfigurations=false \
            --set kube-state-metrics.collectors.validatingwebhookconfigurations=false \
            --set kube-state-metrics.collectors.volumeattachments=false \
            --set kube-state-metrics.collectors.networkpolicies=false \
            --set kube-state-metrics.collectors.verticalpodautoscalers=false \
            --set clusterAgent.enabled=true \
            --set clusterAgent.metricsProvider.enabled=true \
            stable/datadog --set targetSystem=linux
            echo "datadog-cluster-agent installed"
    elif [[ $(get_helm_command_for_release "datadog" "datadog-cluster-agent") == "upgrade" && $enable_datadog == "yes" ]]
    then
        echo "upgrading datadog-cluster-agent..."
        helm upgrade --install --namespace "datadog" --values ./upgrade.yaml --values ./datadog/datadog-values.yaml \
            datadog-cluster-agent \
            --set datadog.apiKeyExistingSecret=datadog-secret \
            --set datadog.appKeyExistingSecret=datadog-secret \
            --set maas.clusterFQDN=${certificate_dns_name} \
            --set kube-state-metrics.image.tag=v1.8.0 \
            --set kube-state-metrics.collectors.mutatingwebhookconfigurations=false \
            --set kube-state-metrics.collectors.validatingwebhookconfigurations=false \
            --set kube-state-metrics.collectors.volumeattachments=false \
            --set kube-state-metrics.collectors.networkpolicies=false \
            --set kube-state-metrics.collectors.verticalpodautoscalers=false \
            --set clusterAgent.enabled=true \
            --set clusterAgent.metricsProvider.enabled=true \
            stable/datadog --set targetSystem=linux
            echo "datadog-cluster-agent upgraded"
    else
        echo "command: $(get_helm_command_for_release "datadog" "datadog-agent") not initialized for helm datadog.  We will do nothing in this case"
    fi

    echo "helm deployments finished."

    # helm list - show deployments
    echo "listing all helm deployments:"
    helm list --all-namespaces

}

#
# command_destroy:
#   Handles the case where this script is invoked with the destroy command.
#
function command_destroy {
    gcloud container clusters get-credentials ${HELM_cluster_id} --region ${HELM_region} --project ${HELM_project_id}

    # Remove datadog from the cluster
    helm uninstall datadog-agent --namespace datadog || true
    helm uninstall datadog-cluster-agent --namespace datadog || true

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
