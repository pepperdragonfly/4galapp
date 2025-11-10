pipeline {
  agent any
  options { timestamps() }

  environment {
    DOCKERHUB = credentials('dockerhub-cred')       // Username/Password
    DOCKER_REPO = 'pepperdragonfly/4glapp'          // << 변경
    GIT_REPO = 'git@github.com:pepperdragonfly/4galapp.git'
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

    stage('Build') {
      steps {
        script {
          env.GIT_SHA = readFile('.git_sha').trim()
          env.IMAGE_TAG = "${BUILD_NUMBER}-${env.GIT_SHA}"
        }
        sh """
          docker build -t ${DOCKER_REPO}:${IMAGE_TAG} -t ${DOCKER_REPO}:latest .
        """
      }
    }

    stage('Push') {
      steps {
        sh """
          echo "${DOCKERHUB_PSW}" | docker login -u "${DOCKERHUB_USR}" --password-stdin
          docker push ${DOCKER_REPO}:${IMAGE_TAG}
          docker push ${DOCKER_REPO}:latest
          docker logout
        """
      }
    }

    stage('Deploy (kubectl via ansdoc)') {
      steps {
        sshagent(['yes25-ssh']) {
          sh """
            ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} '
              set -e
              kubectl create namespace ${K8S_NS} --dry-run=client -o yaml | kubectl apply -f -
              # 선택: ansdoc에 k8s 매니페스트 동기화(미리 배치돼 있다면 생략)
              # cd ~/repo && git pull --ff-only

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
