#!/bin/bash
set -eu${DEBUG+x}o pipefail

if (( $# == 0 )); then
    set -- help
fi

# assign arguments to variables
for i in "$@"
do
  case $i in
    -cn=*|--command_name=*)
    command_name="${i#*=}"
    shift
    ;;
    -ns=*|--namespace=*)
    namespace="${i#*=}"
    shift
    ;;
  esac
done

# required:  namespace, command_name
if [ -z "$namespace" ] || [ -z "$command_name" ] 
then
    echo "Error: missing parameter"
    echo ""
    echo "[required] command name: $command_name"
    echo "[required]   namespace: $namespace"
    echo ""
    echo "This command needs to be run with parameters now."
    echo "  Commands are specified as --command_name=<command> or"
    echo "  -cn=<command>"
    echo ""
    exit 1
fi

export namespace
export command_name

# Make sure a recognized command was provided.
case $command_name in
  getvaulturis|updatevaulturis|restartdeployments)
    ;;
  *)
    echo "ERROR: Unrecognized mng_vault_addresses.sh command: $command_name"
    echo ""
    echo "valid options are:  getvaulturis, updatevaulturis, restartdeployments"
    echo ""
    exit 1
    ;;
esac

function command_getvaulturis {
    for app in maas-gateway maas-core maas-monitoring
    do
        kubectl get cm -n $namespace -l app=$app -o name | xargs -I{} kubectl get -n $namespace {} -o json | jq .data | sed 's/\\n/\n/g' | grep vault.uri
    done
}

function command_updatevaulturis {
    for app in maas-gateway maas-core maas-monitoring
    do
        kubectl get cm -n $namespace -l app=$app -o name | xargs -I{} kubectl get -n $namespace {} -o yaml  | sed -e 's|https://vault.maas-vault-prod.solace.cloud:8200|https://vault.luay.solace.com:9200|' | kubectl apply -n $namespace -f -
        echo "Verifying vault uri updated for $app"
        kubectl get cm -n $namespace -l app=$app -o name | xargs -I{} kubectl get -n $namespace {} -o json | jq .data | sed 's/\\n/\n/g' | grep vault.uri
    done
}

function command_restartdeployments {
    for app in maas-gateway maas-core maas-monitoring
    do
        kubectl get deployment -n $namespace -l app=$app -o name | xargs -I{} kubectl rollout restart -n $namespace {}
    done
}

# Invoke the appropriate command_... function, based on the value of the
# command_name variable.
command_$command_name "$@"