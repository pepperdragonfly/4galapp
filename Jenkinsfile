pipeline {
  agent any

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))   // 최근 빌드 로그만 보관
    disableConcurrentBuilds()                        // 중복 실행 방지
  }

  triggers {
    githubPush()   // GitHub Webhook으로 자동 트리거
  }

  environment {
    // --- Git & Docker ---
    GIT_REPO_SSH   = 'git@github.com:pepperdragonfly/4galapp.git'
    GIT_BRANCH     = 'master'
    DOCKER_USER    = 'pepperdragonfly'
    DOCKER_REPO    = '4glapp'
    DOCKER_IMAGE   = "${DOCKER_USER}/${DOCKER_REPO}"

    // --- 서버 IP ---
    ANSDOC_HOST    = '10.0.2.171'
    MASTERNOD_HOST = '10.0.2.213'
  }

  stages {

    /* ========== 1) Checkout ========== */
    stage('Checkout') {
      steps {
        checkout([
          $class: 'GitSCM',
          branches: [[name: "*/${env.GIT_BRANCH}"]],
          userRemoteConfigs: [[
            url: env.GIT_REPO_SSH,
            credentialsId: 'github-ssh'       // GitHub SSH 크리덴셜
          ]]
        ])
      }
    }

    /* ========== 2) SSH 연결 스모크 테스트 ========== */
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

    /* ========== 3) Build & Push (ansdoc에서 Docker 빌드/푸시) ========== */
    stage('Build & Push on ansdoc') {
      steps {
        sshagent(credentials: ['ansdoc-ssh']) {
          withCredentials([usernamePassword(credentialsId: 'dockerhub-cred',
                                            usernameVariable: 'DH_USER',
                                            passwordVariable: 'DH_PASS')]) {
            // 주의: Groovy 인터폴레이션 금지(비번 안전) → ''' 사용
            sh '''
              set -e

              # 태그(커밋 7자리; 없으면 날짜로 대체)
              if [ -n "$GIT_COMMIT" ]; then
                TAG_SHORT=$(printf "%s" "$GIT_COMMIT" | cut -c1-7)
              else
                TAG_SHORT=$(date +%Y%m%d%H%M)
              fi
              IMG="${DOCKER_IMAGE}:${TAG_SHORT}"

              # (1) DockerHub 로그인 - 비밀번호는 표준입력으로만 전달 (로그/히스토리 무노출)
              printf "%s" "$DH_PASS" | ssh -o StrictHostKeyChecking=no yes25@$ANSDOC_HOST \
                "docker login -u \"$DH_USER\" --password-stdin"

              # (2) 원격에서 빌드/푸시
              ssh -o StrictHostKeyChecking=no yes25@$ANSDOC_HOST bash -lc "
                set -e
                mkdir -p ~/app && cd ~/app

                # 소스 동기화 (최초만 clone, 이후에는 pull)
                if [ ! -d .git ]; then
                  git clone --depth=1 https://github.com/pepperdragonfly/4galapp.git .
                else
                  git pull --ff-only || true
                fi

                # Dockerfile은 리포에 있다고 가정
                docker build -t $IMG .
                docker push $IMG

                docker tag  $IMG ${DOCKER_IMAGE}:latest
                docker push ${DOCKER_IMAGE}:latest
              "

              echo "Built & Pushed: $IMG and ${DOCKER_IMAGE}:latest"
            '''
          }
        }
      }
    }

    /* ========== 4) Deploy (masternod에서 kubectl 롤링 업데이트) ========== */
    stage('Deploy from masternod (kubectl)') {
      steps {
        sshagent(credentials: ['masternod-ssh']) {
          // 여기서는 로컬에서 값 확정 후 원격에 적용
          sh '''
            set -e
            DEPLOY="webapp"       # 실제 배포 리소스명에 맞게 수정
            NS="default"          # 네임스페이스 맞게 수정
            IMG="${DOCKER_IMAGE}:latest"

            ssh -o StrictHostKeyChecking=no yes25@${MASTERNOD_HOST} bash -lc "
              set -e
              echo 'Rolling update to '"$IMG"'...'
              kubectl set image deployment/${DEPLOY} ${DEPLOY}=${IMG} -n ${NS}
              kubectl rollout status deployment/${DEPLOY} -n ${NS}
              kubectl get deploy/${DEPLOY} -n ${NS} -o wide
              kubectl get pods -n ${NS} -o wide
            "
          '''
        }
      }
    }
  }

  post {
    success {
      echo "✅ [SUCCESS] ${DOCKER_IMAGE}:latest built & deployed."
    }
    failure {
      echo "❌ [FAILURE] Check the console log above."
    }
  }
}
