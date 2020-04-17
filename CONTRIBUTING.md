# Contributing
## Test Strategy
A basic sanity test consists of:
1. Deploying the version of the infrastructure that exists in production (indicated by the `production` tag)
1. Initializing and unsealing the Vault and adding test data
1. Performing an upgrade to the latest version
1. Testing that the upgraded Vault instance is running, unsealed, and test data can be retrieved