#!/bin/bash
set eu${DEBUG+x}o pipefail

while [[ -z ${VAULT_ADDR:-} ]]; do
    echo "No VAULT_ADDR specified"
    read -p "Enter value for VAULT_ADDR: " VAULT_ADDR
done

export VAULT_ADDR

vault status

if [[ -z ${VAULT_TOKEN:-} ]]; then
    echo "No Vault token set in the VAULT_TOKEN environment variable."
    exit 1
fi

#
# More tests go here.
#
