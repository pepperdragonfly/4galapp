pipeline {
  agent any

  options {
    timestamps()
    skipDefaultCheckout()
  }

  environment {
    REPO_SSH     = 'git@github.com:pepperdragonfly/4galapp.git'
    DOCKER_IMAGE = 'pepperdragonfly/4glapp'
    ANSDOC_IP    = '10.0.2.171'  // ansdoc
    MASTER_IP    = '10.0.2.213'  // masternod
    DEPLOY       = 'webapp'
    NAMESPACE    = 'default'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          userRemoteConfigs: [[url: env.REPO_SSH, credentialsId: 'github-ssh']]
        ])
      }
    }

    stage('SSH quick test') {
      steps {
        sshagent (credentials: ['ansdoc-ssh']) {
          sh 'ssh -o StrictHostKeyChecking=no yes25@${ANSDOC_IP} "hostname && whoami"'
        }
        sshagent (credentials: ['masternod-ssh']) {
          sh 'ssh -o StrictHostKeyChecking=no yes25@${MASTER_IP} "hostname && whoami"'
        }
      }
    }

    stage('Build & Push on ansdoc') {
      steps {
        sshagent (credentials: ['ansdoc-ssh']) {
          withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            // 여기서 Groovy 보간 없이 쉘에서만 변수 확장되도록 ''' 사용
            sh '''#!/usr/bin/env bash
              set -euo pipefail

              TAG_SHORT=$(printf %s "$GIT_COMMIT" | cut -c1-7)
              echo "[build] TAG_SHORT=${TAG_SHORT}"

              # 원격(ansdoc)에서 빌드/푸시 수행 (heredoc으로 안전하게 전달)
              ssh -o StrictHostKeyChecking=no yes25@${ANSDOC_IP} bash -s <<REMOTE
set -euo pipefail

echo "\${DH_PASS}" | docker login -u "\${DH_USER}" --password-stdin

mkdir -p ~/app && cd ~/app
if [ ! -d .git ]; then
  git clone --depth=1 https://github.com/pepperdragonfly/4galapp.git .
else
  git pull --ff-only || true
fi

docker build -t ${DOCKER_IMAGE}:${TAG_SHORT} .
docker push ${DOCKER_IMAGE}:${TAG_SHORT}

docker tag ${DOCKER_IMAGE}:${TAG_SHORT} ${DOCKER_IMAGE}:latest
docker push ${DOCKER_IMAGE}:latest

echo "[build] pushed: ${DOCKER_IMAGE}:${TAG_SHORT} and :latest"
REMOTE
            '''
          }
        }
      }
    }

    stage('Deploy from masternod (kubectl)') {
      steps {
        sshagent (credentials: ['masternod-ssh']) {
          sh '''#!/usr/bin/env bash
            set -euo pipefail
            TAG_SHORT=$(printf %s "$GIT_COMMIT" | cut -c1-7)
            IMG="${DOCKER_IMAGE}:${TAG_SHORT}"

            ssh -o StrictHostKeyChecking=no yes25@${MASTER_IP} bash -s <<REMOTE
set -euo pipefail
echo "Rolling update to ${IMG} ..."
kubectl set image deployment/${DEPLOY} ${DEPLOY}=${IMG} -n ${NAMESPACE}
kubectl rollout status deployment/${DEPLOY} -n ${NAMESPACE} --timeout=180s
kubectl get deploy/${DEPLOY} -n ${NAMESPACE} -o wide
kubectl get pods -n ${NAMESPACE} -l app=${DEPLOY} -o wide
REMOTE
          '''
        }
      }
    }
  } // stages

  post {
    success {
      echo "✅ [SUCCESS] ${env.DOCKER_IMAGE}:${env.GIT_COMMIT.take(7)} built & deployed."
    }
    failure {
      echo '❌ [FAILURE] Pipeline failed. Check console log.'
    }
  }
}

