@Library(['maas-jenkins-library@master']) _

pipeline {
  agent {
    kubernetes {
      label "build-service-${UUID.randomUUID().toString().substring(0, 8)}"
      yaml """
      apiVersion: v1
      kind: Pod
      spec:
        containers:
          - name: docker
            image: docker:18-dind
            securityContext:
              privileged: true
            env:
              - name: DOCKER_HOST
                value: tcp://localhost:2375
            volumeMounts:
              - name: aws-ecr-login
                mountPath: /root/.docker/config.json
                subPath: .dockerconfigjson
        volumes:
          - name: aws-ecr-login
            secret:
              secretName: aws-ecr-login
      """
    }
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  environment {
    WORKPLACE = pwd(tmp: false)
    GIT_COMMIT_SHORT = sh(
        script: "printf \$(git rev-parse --short ${GIT_COMMIT})",
        returnStdout: true
    )
    BRANCH_TAG = "${GIT_BRANCH.replaceAll('/', '_')}"
    TF_CLI_ARGS = "-no-color"
    TF_CLI_ARGS_apply = "-auto-approve"
    TF_CLI_ARGS_destroy = "-auto-approve"
    VAULT_INSTALLER_BASE_IMAGE_TAG = "868978040651.dkr.ecr.us-east-1.amazonaws.com/maas-vault-installer-base:0.1.0"
    VAULT_INSTALLER_DOCKER_ARGS = "-v /root/.config/gcloud:/root/.config/gcloud:rw -v /root/.vault-token:/root/.vault-token:rw -e TF_CLI_ARGS_apply -e TF_CLI_ARGS -e TF_CLI_ARGS_destroy -e TF_IN_AUTOMATION=true"
    VAULT_INSTALLER_IMAGE_NAME = "868978040651.dkr.ecr.us-east-1.amazonaws.com/maas-vault-gcp-cluster"
    VAULT_INSTALLER_IMAGE_TAG = "${VAULT_INSTALLER_IMAGE_NAME}:${BRANCH_TAG}"
    GCP_CREDS = vault path: "gcp/key/maas-vault-gcp-cluster-maas-vault-dev", key: 'private_key_data', engineVersion: '1'
    VAULT_NAME = "vt-${GIT_COMMIT_SHORT}"
  }

  stages {
    stage('Prepare environment') {
      steps {
        container('docker') {
          script {
            currentBuild.displayName = "${VAULT_NAME}"
            sh "mkdir -p ~/.config/gcloud"
            sh "echo ${GCP_CREDS} | base64 -d > ~/.config/gcloud/application_default_credentials.json"
            sh "touch ~/.vault-token"
          }
        }
      }
    }
    stage('Validate templates') {
      steps {
        container('docker') {
          script {
            sh "./deploy_local.sh validate ${VAULT_NAME}"
          }
        }
      }
    }
    stage('Install Vault') {
      steps {
        container('docker') {
          script {
            sh "./deploy_local.sh deploy ${VAULT_NAME}"
          }
        }
      }
    }
    stage('Test Vault') {
      steps {
        container('docker') {
          script {
            try {
              sh "./deploy_local.sh vaultinit ${VAULT_NAME} 60"
              sh "./deploy_local.sh vault ${VAULT_NAME} secrets enable -tls-skip-verify -version=2 -path=secrets kv"
              sh "./deploy_local.sh vault ${VAULT_NAME} kv put -tls-skip-verify secrets/my-secret my-value=${GIT_COMMIT_SHORT}"
              sh "./deploy_local.sh vault ${VAULT_NAME} kv get -tls-skip-verify -field=my-value  secrets/my-secret"
            } catch(err) {
              currentBuild.result = 'FAILURE'
              echo "Failed: ${err}"
              // Uncomment when debugging failed builds
              // input message: "Failed, will uninstall. Proceed?"
            }
          }
        }
      }
    }
    stage('Uninstall Vault') {
      steps {
        container('docker') {
          script {
            // sh "docker run --rm ${VAULT_INSTALLER_DOCKER_ARGS} 868978040651.dkr.ecr.us-east-1.amazonaws.com/maas-vault-gcp-cluster:production deploy vt-${GIT_COMMIT_SHORT}"
            sh "./deploy_local.sh destroy ${VAULT_NAME}"
          }
        }
      }
    }
    stage('Deploy') {
      when {
        expression { GIT_BRANCH == 'master' && currentBuild.result != 'FAILURE' }
      }
      steps {
        container('docker') {
          script {
            sh "docker push ${VAULT_INSTALLER_IMAGE_TAG}"
            sh "docker tag ${VAULT_INSTALLER_IMAGE_TAG} ${VAULT_INSTALLER_IMAGE_TAG}-${GIT_COMMIT_SHORT}"
            sh "docker push ${VAULT_INSTALLER_IMAGE_TAG}-${GIT_COMMIT_SHORT}"
          }
        }
      }
    }
  }
}