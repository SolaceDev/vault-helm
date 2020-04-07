# GCP Storage Transfer
Sets up storage transfer for purposes of backup and restore. Based on the sample provided by Google here: https://github.com/GoogleCloudPlatform/python-docs-samples/blob/master/storage/transfer_service/nearline_request.py

## Pre-requisites
* Python 3
* GCloud CLI

## Setup
* Install requirements.txt with `pip3 install -r requirements.txt`
* Login to GCP with `gcloud auth application-default login`

## How to Run
### Setup Scheduled Backup
* `python3 transfer.py <GCP project> <Source Bucket> <Target Backup Bucket>`
    * Ex. `python3 transfer.py maas-vault-dev maas-vault-dev-vault-dev-data maas-vault-dev-backup`
### Restore From Backup
* `python3 transfer.py <GCP project> <Backup Bucket> <Target Source Bucket> --run-once`
    * Ex. `python3 transfer.py maas-vault-dev maas-vault-dev-backup maas-vault-dev-vault-dev-data --run-once`