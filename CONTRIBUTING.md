# Contributing
## Changing Base Image
When changing library versions or [Terraform dependencies](https://github.com/SolaceDev/maas-vault-gcp-cluster/blob/master/terraform/main.tf),
you will have to update the [base Docker image](https://github.com/SolaceDev/maas-vault-gcp-cluster/blob/master/baseimage/Dockerfile).

After doing so, you'll want to push the update to [ECR](https://console.aws.amazon.com/ecr/repositories/maas-vault-installer-base/?region=us-east-1) with
a new tag and [update the Jenkinsfile to use the new base image](https://github.com/SolaceDev/maas-vault-gcp-cluster/blob/master/Jenkinsfile#L45).

## Changes to Production
When a change is made that is enacted in production, [update the image tag in ECR](https://console.aws.amazon.com/ecr/repositories/maas-vault-gcp-cluster/?region=us-east) so that
the `production` tag points at the correct image. This is so the pipeline continues to test upgrades against the correct load.

## Test Strategy
A basic sanity test consists of:
1. Deploying the version of the infrastructure that exists in production (indicated by the `production` tag)
1. Initializing and unsealing the Vault and adding test data
1. Performing an upgrade to the latest version
1. Testing that the upgraded Vault instance is running, unsealed, and test data can be retrieved