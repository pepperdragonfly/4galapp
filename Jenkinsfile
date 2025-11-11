pipeline {
  agent any

  environment {
    // DockerHub 이미지 이름
    DOCKER_REPO = "4glapp/webapp"
    // Git commit short SHA (빌드 버전 태그로 사용)
    GIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
  }

  stages {

    stage('Checkout') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: '*/main']],
          userRemoteConfigs: [[
            url: 'git@github.com:pepperdragonfly/4galapp.git',
            credentialsId: 'github-ssh'
          ]]
        ])
      }
    }

    stage('Build Docker Image') {
      steps {
        sh """
          echo '🛠️  Building Docker image...'
          docker build -t ${DOCKER_REPO}:${GIT_SHORT} -t ${DOCKER_REPO}:latest .
        """
      }
    }

    stage('Push to DockerHub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh """
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            docker push ${DOCKER_REPO}:${GIT_SHORT}
            docker push ${DOCKER_REPO}:latest
          """
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        sh """
          echo '🚀 Deploying to Kubernetes cluster...'
          # K8s 설정 파일 반영 (GitHub 리포에 있는 k8s/*.yaml)
          kubectl apply -f k8s/service.yaml
          kubectl apply -f k8s/deployment.yaml

          # 새 이미지로 롤링 업데이트
          kubectl set image deployment/yes25-webapp webapp=${DOCKER_REPO}:${GIT_SHORT}
          kubectl rollout status deployment/yes25-webapp --timeout=120s
        """
      }
    }
  }

  post {
    success {
      echo "✅ 배포 성공: ${DOCKER_REPO}:${GIT_SHORT}"
    }
    failure {
      echo "❌ 배포 실패! 이전 버전으로 롤백합니다."
      sh 'kubectl rollout undo deployment/yes25-webapp || true'
    }
  }
}
