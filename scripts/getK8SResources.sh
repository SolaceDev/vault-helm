#!/bin/bash

#namespaces
namespaces=("vault" "cert-manager")

for ns in "${namespaces[@]}"
do
   :

   echo "Getting all resources from namespae $ns"

   context=`kubectl config set-context --current --namespace=$ns`

   dir=$(mkdir -p $HOME/vault_resources/$ns/pods \
                  $HOME/vault_resources/$ns/services \
                  $HOME/vault_resources/$ns/statefulsets \
                  $HOME/vault_resources/$ns/deployments \
                  $HOME/vault_resources/$ns/secrets \
                  $HOME/vault_resources/$ns/service_accounts)

   pods=($(kubectl get pods -n $ns -o jsonpath='{.items[*].metadata.name}'))
   services=($(kubectl get services -n $ns -o jsonpath='{.items[*].metadata.name}'))
   statefulsets=($(kubectl get statefulsets -n $ns -o jsonpath='{.items[*].metadata.name}'))
   deployments=($(kubectl get deployments -n $ns -o jsonpath='{.items[*].metadata.name}'))
   secrets=($(kubectl get secrets -n $ns -o jsonpath='{.items[*].metadata.name}'))
   service_accounts=($(kubectl get serviceaccounts -n $ns -o jsonpath='{.items[*].metadata.name}'))

   
   echo "Getting Pods..."
   for p in "${pods[@]}"
   do
      :
      pod=$(kubectl get pod $p -o yaml >> $HOME/vault_resources/$ns/pods/$p)           
   done

   echo "Getting Services..."
   for srv in "${services[@]}"
   do
      :
      service=$(kubectl get service $srv -o yaml >> $HOME/vault_resources/$ns/services/$srv)           
   done

   echo "Getting Statefulsets..."
   for ss in "${statefulsets[@]}"
   do
      :
      statefulset=$(kubectl get statefulset $ss -o yaml >> $HOME/vault_resources/$ns/statefulsets/$ss)           
   done
   
   echo "Getting Deployments..."
   for d in "${deployments[@]}"
   do
      :
      deployment=$(kubectl get deployment $d -o yaml >> $HOME/vault_resources/$ns/deployments/$d)           
   done

   echo "Getting Secrets..."
   for sec in "${secrets[@]}"
   do
      :
      secret=$(kubectl get secret $sec -o yaml >> $HOME/vault_resources/$ns/secrets/$sec)           
   done

   echo "Getting service accounts..."
   for sa in "${service_accounts[@]}"
   do
      :
      service_account=$(kubectl get serviceaccounts $sa -o yaml >> $HOME/vault_resources/$ns/service_accounts/$sa)           
   done
done