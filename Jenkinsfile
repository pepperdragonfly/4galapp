pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
  }

  triggers {
    githubPush()   // GitHub Webhook
  }

  environment {
    // --- 고정 환경 ---
    GIT_REPO_SSH   = 'git@github.com:pepperdragonfly/4galapp.git'
    GIT_BRANCH     = 'master'              // 필요시 main으로 변경
    DOCKER_USER    = 'pepperdragonfly'
    DOCKER_REPO    = '4glapp'
    DOCKER_IMAGE   = "${env.DOCKER_USER}/${env.DOCKER_REPO}"

    // --- 서버 IP ---
    ANSDOC_HOST    = '10.0.2.171'
    MASTERNOD_HOST = '10.0.2.213'
  }

  stages {

    stage('Checkout') {
      steps {
        // GitHub SSH 키: github-ssh (없으면 UI에서 생성)
        checkout([
          $class: 'GitSCM',
          branches: [[name: "*/${env.GIT_BRANCH}"]],
          userRemoteConfigs: [[
            url: env.GIT_REPO_SSH,
            credentialsId: 'github-ssh'
          ]]
        ])
      }
    }

    stage('SSH quick test') {
      steps {
        sshagent(credentials: ['ansdoc-ssh']) {
          sh 'ssh -o StrictHostKeyChecking=no yes25@${ANSDOC_HOST} "hostname && whoami"'
        }
        sshagent(credentials: ['masternod-ssh']) {
          sh 'ssh -o StrictHostKeyChecking=no yes25@${MASTERNOD_HOST} "hostname && whoami"'
        }
      }
    }

    stage('Build & Push on ansdoc') {
      steps {
        sshagent(credentials: ['ansdoc-ssh']) {
          withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh '''
              ssh -o StrictHostKeyChecking=no yes25@${ANSDOC_HOST} bash -lc '
                set -e
                echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin

                # 작업 디렉토리 준비
                mkdir -p ~/app && cd ~/app

                # 소스 동기화 (리포를 직접 클론하고 싶으면 주석 해제)
                # test -d .git || git clone --depth=1 https://github.com/pepperdragonfly/4galapp.git .
                # git pull --ff-only || true

                # Dockerfile은 리포에 있다고 가정 (필요하면 경로 수정)
                TAG_SHORT=$(echo ${GIT_COMMIT} | cut -c1-7)

                docker build -t ${DOCKER_IMAGE}:${TAG_SHORT} .
                docker push ${DOCKER_IMAGE}:${TAG_SHORT}

                docker tag  ${DOCKER_IMAGE}:${TAG_SHORT} ${DOCKER_IMAGE}:latest
                docker push ${DOCKER_IMAGE}:latest
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
            ssh -o StrictHostKeyChecking=no yes25@${MASTERNOD_HOST} bash -lc '
              set -e
              # 배포 리소스 이름/네임스페이스 맞게 수정
              NS=default
              DEPLOY=webapp

              # 최신 이미지로 롤링 업데이트
              kubectl set image deploy/${DEPLOY} ${DEPLOY}=${DOCKER_IMAGE}:latest -n ${NS}
              kubectl rollout status deploy/${DEPLOY} -n ${NS}
              kubectl get deploy/${DEPLOY} -n ${NS} -o wide
            '
          '''
        }
      }
    }
  }

  post {
    success {
      echo "✅ Deploy OK: ${env.DOCKER_IMAGE}:latest"
    }
    failure {
      echo "❌ Pipeline failed"
      // 필요하면 여기서 알림(Webhook/Slack 등) 추가
    }
  }
}

