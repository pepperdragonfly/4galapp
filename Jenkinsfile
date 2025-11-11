pipeline {
  agent any

  // 빌드 폭주/리소스 관리 & 로그 관리
  options {
    timeout(time: 30, unit: 'MINUTES')
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '5'))
    rateLimitBuilds(throttle: [count: 1, durationName: 'minute']) // 1분에 1회
    quietPeriod(15) // 웹훅 연속 발생 시 15초간 묶어서 처리
    timestamps()
  }

  environment {
    // 대상 호스트/리소스
    ANSDOC     = '10.0.2.171'
    MASTERNOD  = '10.0.2.213'
    NAMESPACE  = 'default'
    DEPLOYMENT = 'webapp'

    // 이미지 네임 (고정)
    DOCKER_IMAGE = 'pepperdragonfly/4glapp'

    // 변경 감지: 이 경로들 변경 없으면 Build/Deploy 단계 스킵
    CHANGE_GLOBS = "Dockerfile\nsrc/**\nk8s/**\nJenkinsfile"
  }

  triggers {
    // GitHub 웹훅 사용이 기본. 폴링은 비활성화(원하면 아래 주석 해제 후 간격 늘려서 사용)
    // pollSCM('@monthly')
  }

  stages {

    stage('Checkout') {
      steps {
        // Jenkins Declarative 기본 Checkout을 사용하되, 여기서도 한 번 명시적으로 보장
        checkout scm
      }
    }

    stage('Compute META & Early Skip') {
      steps {
        script {
          // 안전하게 커밋 정보 취득
          env.TAG_SHORT  = sh(returnStdout: true, script: 'git rev-parse --short=7 HEAD').trim()
          env.COMMIT_MSG = sh(returnStdout: true, script: 'git log -1 --pretty=%B').trim()
          echo "TAG_SHORT=${env.TAG_SHORT}"
          echo "Last commit message: ${env.COMMIT_MSG}"

          // [ci skip] / [skip ci] 시 전체 파이프라인 스킵
          if (env.COMMIT_MSG =~ /\\[(ci skip|skip ci)\\]/i) {
            currentBuild.description = "Skipped by commit message"
            echo '[SKIP] Commit message requested to skip CI.'
            // 이후 stage에서 when 조건으로 자연스럽게 스킵되도록 플래그만 남김
            env.CI_SKIP_ALL = 'true'
          }

          // 변경 파일 필터(대상 glob 이외 변경이면 스킵)
          writeFile file: 'ci_globs.txt', text: env.CHANGE_GLOBS + "\n"
          def changed = sh(returnStatus: true, script: '''
            set -e
            # 최신 커밋만 비교(웹훅 시 대부분 single commit)
            git diff-tree --no-commit-id --name-only -r HEAD > .changed_files
            # glob 매칭
            awk 1 ci_globs.txt | while read -r G; do
              [ -z "$G" ] && continue
              git check-ignore -v -n --stdin >/dev/null 2>&1 || true
            done
            # 간단 매칭: grep -E 로 처리
            # glob을 정규식으로 대충 변환(* -> .*)
            REGEX=$(sed -E "s/[.]/\\\\./g; s/\\*/.*/g" ci_globs.txt | paste -sd'|' -)
            if [ -s .changed_files ] && echo "$REGEX" | grep -q '[^[:space:]]'; then
              if grep -E "$REGEX" .changed_files >/dev/null; then
                exit 0
              else
                exit 3
              fi
            fi
          ''')
          if (changed == 3) {
            env.CI_SKIP_BUILD = 'true'
            echo '[SKIP] No relevant file changes for build/deploy.'
          }
        }
      }
    }

    stage('SSH quick test') {
      when {
        expression { return env.CI_SKIP_ALL != 'true' }
      }
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
          expression { return env.CI_SKIP_ALL != 'true' }
          expression { return env.CI_SKIP_BUILD != 'true' }
        }
      }
      options { timeout(time: 25, unit: 'MINUTES') }
      steps {
        sshagent(credentials: ['ansdoc-ssh']) {
          withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            // 1) 로그인은 로컬에서 비번 stdin → 원격 docker login
            sh """
              set -e
              printf '%s' "\$DH_PASS" | ssh -o StrictHostKeyChecking=no yes25@${env.ANSDOC} 'docker login -u '"\${DH_USER}"' --password-stdin'
            """

            // 2) 원격에서 clone/pull + build + push (heredoc로 안전하게 전달)
            sh """
              set -e
              ssh -o StrictHostKeyChecking=no yes25@${env.ANSDOC} 'bash -s' <<'EOS'
              set -e
              mkdir -p ~/app && cd ~/app

              if [ ! -d .git ]; then
                git clone --depth=1 https://github.com/pepperdragonfly/4galapp.git .
              else
                git pull --ff-only || true
              fi

              # 도커 빌드/푸시: immutable tag + latest 동시
              docker build -t ${env.DOCKER_IMAGE}:${env.TAG_SHORT} .
              docker push ${env.DOCKER_IMAGE}:${env.TAG_SHORT}

              docker tag  ${env.DOCKER_IMAGE}:${env.TAG_SHORT} ${env.DOCKER_IMAGE}:latest
              docker push ${env.DOCKER_IMAGE}:latest
EOS
            """
            echo "Built & Pushed: ${env.DOCKER_IMAGE}:${env.TAG_SHORT} and :latest"
          }
        }
      }
    }

    stage('Deploy from masternod (kubectl)') {
      when {
        allOf {
          expression { return env.CI_SKIP_ALL != 'true' }
          expression { return env.CI_SKIP_BUILD != 'true' }
        }
      }
      steps {
        sshagent(credentials: ['masternod-ssh']) {
          // Immutable 이미지로 롤링 업데이트(rollout)
          sh """
            set -e
            ssh -o StrictHostKeyChecking=no yes25@${env.MASTERNOD} 'bash -lc "
              set -e
              echo Rolling update to ${env.DOCKER_IMAGE}:${env.TAG_SHORT}...
              kubectl set image deployment/${env.DEPLOYMENT} ${env.DEPLOYMENT}=${env.DOCKER_IMAGE}:${env.TAG_SHORT} -n ${env.NAMESPACE}
              kubectl annotate deployment/${env.DEPLOYMENT} -n ${env.NAMESPACE} \\
                ci.tag=${env.TAG_SHORT} ci.time=$(date +%s) --overwrite
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
          expression { return env.CI_SKIP_ALL != 'true' }
          expression { return env.CI_SKIP_BUILD != 'true' }
        }
      }
      steps {
        // 필요 시 간단 헬스체크. ALB DNS가 있으면 ENV로 등록해서 curl 하도록 변경 가능.
        echo 'ℹ️  (옵션) 여기서 NodePort/ALB로 간단 헬스체크 curl 수행 가능'
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
      script {
        // 콘솔에 핵심 메타만 남겨 둠
        echo "Build meta => TAG_SHORT=${env.TAG_SHORT ?: 'n/a'}  SKIP_ALL=${env.CI_SKIP_ALL ?: 'false'}  SKIP_BUILD=${env.CI_SKIP_BUILD ?: 'false'}"
      }
    }
  }
}
