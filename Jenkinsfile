pipeline {
  agent any

  environment {
    DOCKER_REPO = "pepperdragonfly/4glapp"
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
        withCredentials([usernamePassword(credentialsId: 'dockerhub-cred',
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
          sshagent(credentials: ['ansdoc-ssh']) {
            sh '''
              set -e

              # 1) 태그 계산(로컬에서 계산해 원격에 넘김)
              TAG=$(git rev-parse --short HEAD 2>/dev/null || date +%s)
              echo "TAG=$TAG"

              # 2) 코드 동기화
              rsync -az --delete ./ yes25@yes25ansdoc:~/webapp/

              # 3) 원격(ansdoc)에서 빌드
              ssh -o StrictHostKeyChecking=no yes25@yes25ansdoc "bash -lc 'set -e; cd ~/webapp; docker build -t ${DOCKER_REPO}:$TAG -t ${DOCKER_REPO}:latest .'"

              # 4) 원격(ansdoc)에서 로그인 & 푸시
              printf "%s" "$DH_PASS" | ssh -o StrictHostKeyChecking=no yes25@yes25ansdoc "docker login -u \"$DH_USER\" --password-stdin"
              ssh -o StrictHostKeyChecking=no yes25@yes25ansdoc "docker push ${DOCKER_REPO}:$TAG && docker push ${DOCKER_REPO}:latest"
            '''
          }
        }
      }
    }

    stage('Deploy from masternod (kubectl)') {
      steps {
        sshagent(credentials: ['masternod-ssh']) {
          sh '''
            set -e
            # 1) 매니페스트 동기화
            rsync -az --delete ./k8s/ yes25@yes25masternod:~/deploy/k8s/

            # 2) 적용 및 롤링 상태 확인
            ssh -o StrictHostKeyChecking=no yes25@yes25masternod "
              set -e
              kubectl apply -f ~/deploy/k8s/service.yaml
              kubectl apply -f ~/deploy/k8s/deployment.yaml
              kubectl rollout status deployment/yes25-webapp --timeout=180s
            "
          '''
        }
      }
    }
  }

  post {
    success {
      echo "✅ Deployed: ${env.DOCKER_REPO}:latest"
    }
    failure {
      sshagent(credentials: ['masternod-ssh']) {
        sh '''
          ssh -o StrictHostKeyChecking=no yes25@yes25masternod "kubectl rollout undo deployment/yes25-webapp || true"
        '''
      }
      echo "❌ Failed — rollback attempted"
    }
  }
}
