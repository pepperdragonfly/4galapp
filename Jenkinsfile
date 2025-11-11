pipeline {
  agent any

  environment {
    DOCKER_REPO = "4glapp/webapp"
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

    stage('Build & Push on ansdoc') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sshagent(credentials: ['ansdoc-ssh']) {
            sh '''
              # 최신 코드 동기화
              rsync -az --delete ./ yes25@yes25ansdoc:~/webapp/

              # ansdoc에서 Docker 빌드/푸시
              ssh -o StrictHostKeyChecking=no yes25@yes25ansdoc '
                set -e
                cd ~/webapp &&
                TAG=$(git rev-parse --short HEAD 2>/dev/null || date +%s) &&
                docker build -t '"${DOCKER_REPO}"':$TAG -t '"${DOCKER_REPO}"':latest . &&
                echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin &&
                docker push '"${DOCKER_REPO}"':$TAG &&
                docker push '"${DOCKER_REPO}"':latest &&
                echo "Pushed: '"${DOCKER_REPO}"':$TAG"
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
            # 매니페스트만 마스터로 동기화
            rsync -az --delete ./k8s/ yes25@yes25masternod:~/deploy/k8s/

            # masternod에서 apply + 롤링 업데이트 확인
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
    success {
      echo "✅ 배포 성공"
    }
    failure {
      sshagent(credentials: ['masternod-ssh']) {
        sh '''
          ssh -o StrictHostKeyChecking=no yes25@yes25masternod '
            kubectl rollout undo deployment/yes25-webapp || true
          '
        '''
      }
      echo "❌ 실패 — 롤백 시도"
    }
  }
}

