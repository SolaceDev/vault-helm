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
    IMAGE_TAG = "${GIT_BRANCH}-${GIT_COMMIT_SHORT}"
    VAULT_INSTALLER_BASE_IMAGE_TAG = "868978040651.dkr.ecr.us-east-1.amazonaws.com/maas-vault-installer-base:0.1.0"
    VAULT_INSTALLER_DOCKER_ARGS = " "
  }

  stages {
    stage('Test') {
      steps {
        container('docker') {
          script {
            sh "./deploy_local.sh test vault-test"
          }
        }
      }
    }
  }
}