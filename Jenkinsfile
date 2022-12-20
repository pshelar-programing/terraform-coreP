#!groovy

// When a PR -> main is opened, we want to run tf init, fmt, validate, plan
    // When a plan is complete, it should comment the changes on the PR
    // Need to store .plan file in accessible location
    // Update the PR build status in GitHub

// When a PR is accepted, we want to run tf apply
    // should be able to use the .plan file from PR
@Library('jenkins-shared-library') _
import LoadConfig

pipeline {
  agent {
    docker {
      image "${LCP_IAC_IMAGE}"
      registryUrl "${LCP_REGISTRY_URL}"
      registryCredentialsId 'LEARNING-PLATFORM-QUAY'
      args '-u root:root'
      reuseNode true
    }
  }
  environment {
    BUILD_NAME    = "${env.JOB_NAME.split('/')[2]}"
    BRANCH_NAME = "${env.JOB_NAME.split('/')[3]}"
    GH_HOST       = 'wwwin-github.cisco.com'
    IMAGE_TAG = "${env.JOB_NAME.split('/')[3]}_${env.BUILD_NUMBER}_${env.GIT_COMMIT.substring(0, 6)}"
    IMAGE_NAME = 'iac'
  }
  options {
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '5'))
    disableConcurrentBuilds()
  }

  stages {
    stage('Setup') {
      steps {
        script {
          tempConfig = getConfig()
          params.environment = tempConfig.config.environment
          print params.environment
          if (params.environment == 'development') {
            aws_region = 'us-east-1'
            awsCredentials = 'lcp-terraform-dev'
            s3_bucket = 'lcp-terraform-development'
          }
          else if (params.environment == 'testing') {
            aws_region = 'us-east-2'
            awsCredentials = 'lcp-terraform-dev'
            s3_bucket = 'lcp-terraform-testing'
          }
          else if (params.environment == 'staging') {
            aws_region = 'us-east-1'
            awsCredentials = 'lcp-terraform-stage'
            s3_bucket = 'lcp-terraform-staging'
          }
          else if (params.environment == 'performance') {
            aws_region = 'us-east-2'
            awsCredentials = 'lcp-terraform-stage'
            s3_bucket = 'lcp-terraform-performance'
          }
          else if (params.environment == 'production') {
            aws_region = 'us-east-1'
            awsCredentials = 'lcp-terraform-prod'
            s3_bucket = 'lcp-terraform-production'
          }
        }
      }
    }
    stage('S3 Copy') {
      steps {
        script {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${awsCredentials}"]]) {
            wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
              dir('modules/aws/bastion') {
                sh """
                  aws s3 cp s3://${s3_bucket}/terraform/bastion-keys . --sse --region ${aws_region} --recursive
                """
              }
            }
          }
        }
      }
    }
    stage('TF Validate') {
      steps {
        script {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${awsCredentials}"]]) {
            wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
              dir('resources') {
                sh """
                  terraform init -force-copy \
                    -backend-config="bucket=${s3_bucket}" \
                    -backend-config=dynamodb_table="terraform_state" \
                    -backend-config='key=terraform/tfstate' \
                    -backend-config="region=${aws_region}"
                  terraform validate
                """
              }
            }
          }
        }
      }
    }
    stage('TF Plan') {
      when {
        anyOf {
          branch 'main'
          changeRequest()
        }
      }
      steps {
        script {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${awsCredentials}"]]) {
            wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
              dir('resources') {
                sh """
                  terraform workspace select ${params.environment}
                  terraform plan -input=false -out tfplan \
                    -no-color -var-file="../vars/${params.environment}.tfvars"
                  terraform show -no-color tfplan > tfplan.txt
                """
              }
            }
          }
        }
      }
    }

    stage('TF PR Comment') {
      when { changeRequest() }
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: '386fd8ce-11bc-4765-9384-b3adb033e789', passwordVariable: 'TOKEN', usernameVariable: 'username')]){
            wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
              dir('resources') {
                sh '''
                  git config --global --add safe.directory $WORKSPACE
                  echo $TOKEN | gh auth login --with-token -h $GH_HOST
                  gh pr comment $CHANGE_ID --body-file tfplan.txt
                  gh auth logout -h $GH_HOST
                '''
              }
            }
          }
        }
      }
    }
    stage(' Manual Approval') {
      when {
        anyOf {
          expression { params.environment == 'testing' }
          expression { params.environment == 'staging' }
          expression { params.environment == 'performance' }
          expression { params.environment == 'production' }
        }
      }
      steps {
        dir('resources') {
          script {
            def plan = readFile 'tfplan.txt'
              input message: 'Do you want to apply the plan?',
              parameters: [text(name: 'Plan', description: 'Please review the plan', defaultValue: plan)]
          }
        }
      }
    }
    stage('TF Apply') {
      when {
        branch 'main'
      }
      steps {
        script {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${awsCredentials}"]]) {
            wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
              dir('resources') {
              sh '''
                service=$(cat config.json | grep -i "service" | awk '{print$2}' |tr -d '",')
                environment=$(cat config.json | grep -i "environment" | awk '{print$2}' |tr -d '",')
                action=$(cat config.json | grep -i "action" | awk '{print$2}' |tr -d '",')
                (cd services/$service && terraform ${action} -compact-warnings --var-file=environment/${environment}.tfvars)
                terraform apply -no-color -input=false -auto-approve tfplan
                '''
              }
            }
          }
        }
      }
    }
  }
  post {
    always {
      cleanWs deleteDirs: true
    }
  }
}
