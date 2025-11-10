pipeline {
  agent any

  environment {
    DOCKERHUB_CREDENTIALS = credentials('dockerhub-cred')   // Jenkins Credentials ID
    DOCKERHUB_REPO = 'yes25/webapp'                         // DockerHub repo
    KUBE_SSH_HOST = 'yes25ansdoc'                           // ansible/k8s master host alias
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        echo '✅ GitHub 코드 체크아웃 완료'
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          sh '''
          docker build -t $DOCKERHUB_REPO:latest .
          '''
        }
      }
    }

    stage('Push to DockerHub') {
      steps {
        script {
          sh '''
          echo "$DOCKERHUB_CREDENTIALS_PSW" | docker login -u "$DOCKERHUB_CREDENTIALS_USR" --password-stdin
          docker push $DOCKERHUB_REPO:latest
          '''
        }
      }
    }

    stage('Rolling Update on K8s') {
      steps {
        script {
          sh '''
          ssh $KUBE_SSH_HOST "kubectl set image deployment/yes25-webapp yes25-webapp=$DOCKERHUB_REPO:latest && kubectl rollout status deployment/yes25-webapp"
          '''
        }
      }
    }
  }

  post {
    success {
      echo '🚀 롤링 업데이트 완료 — 새 버전이 배포되었습니다!'
    }
    failure {
      echo '❌ 빌드 실패 — 콘솔 로그 확인 필요'
    }
  }
}
