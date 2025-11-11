pipeline {
  agent any

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
  }

  triggers {
    githubPush()   // GitHub webhook push 감지
  }

  environment {
    // --- Git & Docker 정보 ---
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

    /* ======= 1. Checkout ======= */
    stage('Checkout') {
      steps {
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

    /* ======= 2. SSH 연결 확인 ======= */
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

    /* ======= 3. Build & Push (ansdoc 서버에서 Docker 빌드/푸시) ======= */
    stage('Build & Push on ansdoc') {
      steps {
        sshagent(credentials: ['ansdoc-ssh']) {
          withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh """
              ssh -o StrictHostKeyChecking=no yes25@${ANSDOC_HOST} "bash -lc \"
                set -e
                echo '${DH_PASS}' | docker login -u '${DH_USER}' --password-stdin

                mkdir -p ~/app && cd ~/app

                # 소스 클론 (필요 시 갱신)
                if [ ! -d .git ]; then
                  git clone --depth=1 https://github.com/pepperdragonfly/4galapp.git .
                else
                  git pull --ff-only || true
                fi

                TAG_SHORT=\\\$(date +%Y%m%d%H%M)

                docker build -t ${DOCKER_IMAGE}:\\\${TAG_SHORT} .
                docker push ${DOCKER_IMAGE}:\\\${TAG_SHORT}

                docker tag  ${DOCKER_IMAGE}:\\\${TAG_SHORT} ${DOCKER_IMAGE}:latest
                docker push ${DOCKER_IMAGE}:latest
              \"
              "
            """
          }
        }
      }
    }

    /* ======= 4. Kubernetes Deploy (masternod에서) ======= */
    stage('Deploy from masternod (kubectl)') {
      steps {
        sshagent(credentials: ['masternod-ssh']) {
          sh """
            ssh -o StrictHostKeyChecking=no yes25@${MASTERNOD_HOST} "bash -lc '
              set -e
              DEPLOY=webapp
              NS=default
              IMG=${DOCKER_IMAGE}:latest

              echo "Rolling update to \$IMG ..."
              kubectl set image deployment/\$DEPLOY \$DEPLOY=\$IMG -n \$NS
              kubectl rollout status deployment/\$DEPLOY -n \$NS
              kubectl get pods -n \$NS -o wide
            '"
          """
        }
      }
    }
  }

  post {
    success {
      echo "✅ [SUCCESS] ${DOCKER_IMAGE}:latest successfully built & deployed."
    }
    failure {
      echo "❌ [FAILURE] Pipeline failed. Check console log."
    }
  }
}
