pipeline {
  agent any

  options {
    timeout(time: 30, unit: 'MINUTES')
    disableConcurrentBuilds()                       // 동시에 여러 빌드 금지
    quietPeriod(15)                                 // 15초 내 중복 웹훅은 묶어서 처리
    rateLimitBuilds(throttle: [count: 1, durationName: 'minute']) // 분당 1회 제한
    buildDiscarder(logRotator(numToKeepStr: '20'))  // 오래된 빌드 자동 삭제
    timestamps()
  }

  triggers {
    githubPush()  // GitHub webhook 자동 트리거
  }

  environment {
    ANSDOC     = '10.0.2.171'
    MASTERNOD  = '10.0.2.213'
    NAMESPACE  = 'default'
    DEPLOYMENT = 'webapp'
    DOCKER_IMAGE = 'pepperdragonfly/4glapp'

    // 변경 감지 기준: 이 경로 이외엔 스킵
    CHANGE_GLOBS = "Dockerfile\nsrc/**\nk8s/**\nJenkinsfile"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Compute META & Change Detection') {
      steps {
        script {
          env.TAG_SHORT  = sh(returnStdout: true, script: 'git rev-parse --short=7 HEAD').trim()
          env.COMMIT_MSG = sh(returnStdout: true, script: 'git log -1 --pretty=%B').trim()
          echo "TAG_SHORT=${env.TAG_SHORT}"
          echo "Commit Message: ${env.COMMIT_MSG}"

          // [ci skip] 커밋은 전체 스킵
          if (env.GIT_COMMIT_MESSAGE =~ /(?i)\[(ci skip|skip ci)\]/) {
            echo '[SKIP] Commit message requested to skip CI.'
            env.CI_SKIP_ALL = 'true'
          }

          // 중요 파일 변경 여부 확인
          writeFile file: 'ci_globs.txt', text: env.CHANGE_GLOBS + "\n"
          def changed = sh(returnStatus: true, script: '''
            set -e
            git diff-tree --no-commit-id --name-only -r HEAD > .changed_files
            REGEX=$(sed -E "s/[.]/\\\\./g; s/\\*/.*/g" ci_globs.txt | paste -sd'|' -)
            if [ -s .changed_files ]; then
              if grep -E "$REGEX" .changed_files >/dev/null; then
                exit 0
              else
                exit 3
              fi
            fi
          ''')
          if (changed == 3) {
            echo '[SKIP] No relevant file changes detected.'
            env.CI_SKIP_BUILD = 'true'
          }
        }
      }
    }

    stage('SSH Quick Test') {
      when { expression { env.CI_SKIP_ALL != 'true' } }
      steps {
        sshagent(credentials: ['ansdoc-ssh']) {
          sh "ssh -o StrictHostKeyChecking=no yes25@${env.ANSDOC} 'hostname && whoami'"
        }
        sshagent(credentials: ['masternod-ssh']) {
          sh "ssh -o StrictHostKeyChecking=no yes25@${env.MASTERNOD} 'hostname && whoami'"
        }
      }
    }

    stage('Build & Push on ansdoc') {
      when {
        allOf {
          expression { env.CI_SKIP_ALL != 'true' }
          expression { env.CI_SKIP_BUILD != 'true' }
        }
      }
      steps {
        sshagent(credentials: ['ansdoc-ssh']) {
          withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh """
              set -e
              printf '%s' "\$DH_PASS" | ssh -o StrictHostKeyChecking=no yes25@${env.ANSDOC} 'docker login -u "\$DH_USER" --password-stdin'
              ssh -o StrictHostKeyChecking=no yes25@${env.ANSDOC} 'bash -s' <<'EOS'
              set -e
              mkdir -p ~/app && cd ~/app
              if [ ! -d .git ]; then
                git clone --depth=1 https://github.com/pepperdragonfly/4galapp.git .
              else
                git pull --ff-only || true
              fi

              docker build -t ${env.DOCKER_IMAGE}:${env.TAG_SHORT} .
              docker push ${env.DOCKER_IMAGE}:${env.TAG_SHORT}

              docker tag ${env.DOCKER_IMAGE}:${env.TAG_SHORT} ${env.DOCKER_IMAGE}:latest
              docker push ${env.DOCKER_IMAGE}:latest
EOS
            """
            echo "✅ Built & pushed: ${env.DOCKER_IMAGE}:${env.TAG_SHORT} (+latest)"
          }
        }
      }
    }

    stage('Deploy from masternod (kubectl)') {
      when {
        allOf {
          expression { env.CI_SKIP_ALL != 'true' }
          expression { env.CI_SKIP_BUILD != 'true' }
        }
      }
      steps {
        sshagent(credentials: ['masternod-ssh']) {
          sh """
            set -e
            ssh -o StrictHostKeyChecking=no yes25@${env.MASTERNOD} 'bash -lc "
              set -e
              echo Rolling update to ${env.DOCKER_IMAGE}:${env.TAG_SHORT}...
              kubectl set image deployment/${env.DEPLOYMENT} ${env.DEPLOYMENT}=${env.DOCKER_IMAGE}:${env.TAG_SHORT} -n ${env.NAMESPACE}
              kubectl rollout status deployment/${env.DEPLOYMENT} -n ${env.NAMESPACE}
              kubectl get deploy/${env.DEPLOYMENT} -n ${env.NAMESPACE} -o wide
              kubectl get pods -l app=${env.DEPLOYMENT} -n ${env.NAMESPACE} -o wide
            "'
          """
        }
      }
    }

    stage('Smoke Check (optional)') {
      when {
        allOf {
          expression { env.CI_SKIP_ALL != 'true' }
          expression { env.CI_SKIP_BUILD != 'true' }
        }
      }
      steps {
        echo 'ℹ️  Optionally: curl or ALB endpoint health-check could be run here.'
      }
    }
  }

  post {
    success {
      echo "✅ [SUCCESS] ${env.DOCKER_IMAGE}:${env.TAG_SHORT} built & deployed."
    }
    aborted {
      echo "🟨 [ABORTED] Build aborted."
    }
    failure {
      echo "❌ [FAILURE] Pipeline failed. Check console log."
    }
    always {
      echo "Build meta => TAG_SHORT=${env.TAG_SHORT ?: 'n/a'} / SKIP_ALL=${env.CI_SKIP_ALL ?: 'false'} / SKIP_BUILD=${env.CI_SKIP_BUILD ?: 'false'}"
    }
  }
}
