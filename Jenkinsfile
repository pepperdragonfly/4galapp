pipeline {
  agent any
  environment {
    // ✅ 여기만 계정/레포로 교체
    DOCKER_REPO = "pepperdragonfly/4glapp"
  }
  stages {
    stage('Checkout') { /* 생략 */ }

    stage('Build & Push on ansdoc') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sshagent(credentials: ['ansdoc-ssh']) {
            sh '''
              rsync -az --delete ./ yes25@yes25ansdoc:~/webapp/

              ssh -o StrictHostKeyChecking=no yes25@yes25ansdoc '
                set -e
                cd ~/webapp &&
                TAG=$(git rev-parse --short HEAD 2>/dev/null || date +%s) &&
                docker build -t '"${DOCKER_REPO}"':$TAG -t '"${DOCKER_REPO}"':latest . &&
                echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin &&
                docker push '"${DOCKER_REPO}"':$TAG &&
                docker push '"${DOCKER_REPO}"':latest
              '
            '''
          }
        }
      }
    }

    stage('Deploy from masternod (kubectl)') {
      steps {
        sshagent(credentials: ['masternod-ssh']) {
          sh '''
            rsync -az --delete ./k8s/ yes25@yes25masternod:~/deploy/k8s/
            ssh -o StrictHostKeyChecking=no yes25@yes25masternod '
              set -e
              kubectl apply -f ~/deploy/k8s/service.yaml
              kubectl apply -f ~/deploy/k8s/deployment.yaml
              kubectl rollout status deployment/yes25-webapp --timeout=180s
            '
          '''
        }
      }
    }
  }
  post {
    success { echo "✅ 배포 성공" }
    failure {
      sshagent(credentials: ['masternod-ssh']) {
        sh '''
          ssh -o StrictHostKeyChecking=no yes25@yes25masternod '
            kubectl rollout undo deployment/yes25-webapp || true
          '
        '''
      }
    }
  }
}
