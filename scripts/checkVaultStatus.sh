#!/bin/bash

# Default vault address if it is not set
if [[ -z "${VAULT_ADDR}" ]]; then
    export VAULT_ADDR="https://vault.maas-vault-prod.solace.cloud:8200"
fi

# Default gcp project ID if it is not set
if [[ -z "${GCP_PROJECT}" ]]; then
    export GCP_PROJECT="maas-vault-prod"
fi

# Default GKE cluster name if it is not set
if [[ -z "${GKE_CLUSTER}" ]]; then
    export GKE_CLUSTER="vault"
fi

# Exit if vault token is not setup
if ! vault token lookup &> /dev/null ; then
    echo "Vault token is not setup. Please run vault login command before executing this script"
    exit 1
fi

# Vault server health check
echo "Running Vault server health check test"
health_check_status_code=`curl -s -o /dev/null -w "%{http_code}" ${VAULT_ADDR}/v1/sys/internal/ui/mounts`
if [[ "${health_check_status_code}" == "200" ]]; then
    echo "Vault server health check test passed"
    echo ""
else
    echo "Vault server health check test failed. Status code: ${health_check_status_code}"
    exit 1
fi

# Verify stored secret
echo "Verifying secret stored in vault server"
secret_value=`vault kv get -field=description kv/automated-test/ebs-controller`
if [[ "${secret_value}" != "This is dummy value" ]]; then
    echo "Stored secret value does not match"
    exit 1
else
    echo "Secret verification test passed"
    echo ""
fi

# Run kubectl command to verify pod status
gcloud config set project ${GCP_PROJECT}
gcloud container clusters get-credentials ${GKE_CLUSTER} --region us-east1 --project ${GCP_PROJECT}
pods=`kubectl get pods -n vault -o jsonpath='{.items[*].metadata.name}'`
echo "Running test to verify all pods status in vault cluster"
if [[ -z "${pods}" ]]; then
    echo "No vault pod is present in the cluster"
    exit 1
else
    echo "The following vault pods are present in the cluster: ${pods}"
fi
for pod in $pods; do
    echo "Checking all container statuses in ${pod}"
    container_statuses=`kubectl get po vault-0 -n vault -o jsonpath='{.status.containerStatuses[*].ready}'`
    for container_status in $container_statuses; do
        if [[ "${container_status}" == "false" ]]; then
            echo "One of the container is not ready in pod ${pod}"
            exit 1
        fi
    done
done
echo "All vault pods are up and running"
echo ""

# Print all secret mounts
echo "Printing all secret mounts present in vault server for verification"
echo "The following secret mounts are present in vault server:"
vault secrets list
