# Datadog helm deployment for vault on kubernetes
This directory will hold everything relevant to datadog deployment on a kubernetes cluster.

This is not a stand-alone helm chart.  We use helm to deploy datadog directly in the file
helm.sh (around line 230).

datadog-values.yaml:

This file holds default DD values specific to maas-vault-gcp-cluster.  Taken directly from here:
https://raw.githubusercontent.com/helm/charts/master/stable/datadog/values.yaml but added values
to enable cluster event collection on kubernetes.