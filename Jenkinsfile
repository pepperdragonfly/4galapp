pipeline {
  agent any
  options { timestamps() }

  environment {
    DOCKERHUB = credentials('dockerhub-cred')
    DOCKER_REPO = 'pepperdragonfly/4glapp'       // <-- DockerHub 경로(4glapp)
    GIT_REPO = 'git@github.com:pepperdragonfly/4galapp.git'  // <-- GitHub 경로(4galapp)
    DEPLOY_USER = 'yes25'
    DEPLOY_HOST = 'yes25ansdoc'
    K8S_NS = 'yes25'
    DEPLOYMENT = 'yes25-webapp'
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main', url: "${GIT_REPO}", credentialsId: 'github-ssh'
        sh 'git rev-parse --short=7 HEAD > .git_sha'
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          env.GIT_SHA = readFile('.git_sha').trim()
          env.IMAGE_TAG = "${BUILD_NUMBER}-${GIT_SHA}"
        }
        sh """
          docker build -t ${DOCKER_REPO}:${IMAGE_TAG} -t ${DOCKER_REPO}:latest .
        """
      }
    }

    stage('Push to DockerHub') {
      steps {
        sh """
          echo "${DOCKERHUB_PSW}" | docker login -u "${DOCKERHUB_USR}" --password-stdin
          docker push ${DOCKER_REPO}:${IMAGE_TAG}
          docker push ${DOCKER_REPO}:latest
          docker logout
        """
      }
    }

    stage('Deploy to Kubernetes (ansdoc)') {
      steps {
        sshagent(['yes25-ssh']) {
          sh """
            ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} '
              set -e
              kubectl create namespace ${K8S_NS} --dry-run=client -o yaml | kubectl apply -f -
              kubectl -n ${K8S_NS} apply -f ~/repo/k8s/namespace.yaml || true
              kubectl -n ${K8S_NS} apply -f ~/repo/k8s/deployment.yaml || true
              kubectl -n ${K8S_NS} apply -f ~/repo/k8s/service.yaml || true
              kubectl -n ${K8S_NS} set image deployment/${DEPLOYMENT} ${DEPLOYMENT}=${DOCKER_REPO}:${IMAGE_TAG} --record
              kubectl -n ${K8S_NS} rollout status deployment/${DEPLOYMENT} --timeout=3m
            '
          """
        }
      }
    }
  }

  post {
    success { echo "✅ Deployed ${DOCKER_REPO}:${IMAGE_TAG}" }
    failure { echo "❌ Pipeline failed. Check logs." }
  }
}
