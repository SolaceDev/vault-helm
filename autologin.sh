#!/bin/bash

# this script simply automated the steps necessary to run deploy_local.sh

gcloud auth login

export VAULT_ADDR=http://vault.maas-vault-prod.solace.cloud:8200

vault login -method=github token=${GITHUB_TOKEN}

vault read -field=private_key_data gcp/key/vault-gcp-cluster-dev | base64 -D > ~/.config/gcloud/application_default_credentials.json

echo "end of script"
