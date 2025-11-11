pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    triggers {
        githubPush()
    }

    environment {
        REGISTRY_REPO = 'pepperdragonfly/4glapp'
        ANSDOC_HOST   = 'yes25@10.0.2.171'
        MASTER_HOST   = 'yes25@10.0.2.213'
        NS            = 'default'
        DEPLOY        = 'webapp'

        GITHUB_SSH_CRED_ID = 'github-ssh'
        ANSDOC_SSH_CRED_ID = 'ansdoc-ssh'
        MASTER_SSH_CRED_ID = 'masternod-ssh'

        // 실제 DockerHub Credential ID (Username+Password 타입)
        DOCKERHUB_CRED_ID  = 'dockerhub-cred'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.TAG_SHORT = env.GIT_COMMIT?.take(7) ?: sh(returnStdout: true, script: "git rev-parse --short=7 HEAD").trim()
                    echo "Commit tag: ${env.TAG_SHORT}"
                }
            }
        }

        stage('SSH quick test') {
            steps {
                sshagent(credentials: [env.ANSDOC_SSH_CRED_ID]) {
                    sh "ssh -o StrictHostKeyChecking=no ${ANSDOC_HOST} 'hostname && whoami'"
                }
                sshagent(credentials: [env.MASTER_SSH_CRED_ID]) {
                    sh "ssh -o StrictHostKeyChecking=no ${MASTER_HOST} 'hostname && whoami'"
                }
            }
        }

        stage('Preflight: DockerHub login check (ansdoc)') {
            steps {
                sshagent(credentials: [env.ANSDOC_SSH_CRED_ID]) {
                    withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CRED_ID, usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
                        sh '''
                            set -euo pipefail
                            # 로컬 변수(DH_USER/DH_PASS)를 로컬에서 확장 → 원격으로 전달
                            ssh -o StrictHostKeyChecking=no ${ANSDOC_HOST} "printf '%s' \"$DH_PASS\" | docker login -u \"$DH_USER\" --password-stdin 1>/dev/null && docker logout 1>/dev/null || true"
                            echo "[OK] DockerHub login succeeded on ansdoc"
                        '''
                    }
                }
            }
        }

        stage('Build & Push (ansdoc)') {
            steps {
                sshagent(credentials: [env.ANSDOC_SSH_CRED_ID]) {
                    withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CRED_ID, usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
                        sh '''
                            set -euo pipefail

                            # 로그인
                            ssh -o StrictHostKeyChecking=no ${ANSDOC_HOST} "printf '%s' \"$DH_PASS\" | docker login -u \"$DH_USER\" --password-stdin"

                            # 소스 동기화 및 빌드/푸시
                            ssh -o StrictHostKeyChecking=no ${ANSDOC_HOST} "mkdir -p ~/app && cd ~/app && \
                              ( [ ! -d .git ] && git clone --depth=1 https://github.com/pepperdragonfly/4galapp.git . || (git fetch --all --prune && git reset --hard origin/master) ) && \
                              docker build -t ${REGISTRY_REPO}:${TAG_SHORT} . && \
                              docker push  ${REGISTRY_REPO}:${TAG_SHORT} && \
                              docker tag   ${REGISTRY_REPO}:${TAG_SHORT} ${REGISTRY_REPO}:latest && \
                              docker push  ${REGISTRY_REPO}:latest && \
                              docker logout || true"
                        '''
                    }
                }
            }
        }

        stage('Deploy (kubectl on master)') {
            steps {
                sshagent(credentials: [env.MASTER_SSH_CRED_ID]) {
                    sh '''
                        set -euo pipefail
                        ssh -o StrictHostKeyChecking=no ${MASTER_HOST} "echo 'Rolling update to ${REGISTRY_REPO}:${TAG_SHORT} ...' && \
                          kubectl set image deployment/${DEPLOY} ${DEPLOY}=${REGISTRY_REPO}:${TAG_SHORT} -n ${NS} && \
                          kubectl rollout status deployment/${DEPLOY} -n ${NS} --timeout=180s && \
                          kubectl annotate deployment/${DEPLOY} -n ${NS} kubernetes.io/change-cause='Set ${DEPLOY} image to ${REGISTRY_REPO}:${TAG_SHORT}' --overwrite && \
                          kubectl get deploy/${DEPLOY} -n ${NS} -o wide && \
                          kubectl get pods -n ${NS} -l app=${DEPLOY} -o wide && \
                          kubectl get pods -n ${NS} -l app=${DEPLOY} -o jsonpath='{range .items[*]}{.metadata.name}{\"  \"}{.status.containerStatuses[0].imageID}{\"\\n\"}{end}'"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ SUCCESS: ${REGISTRY_REPO}:${TAG_SHORT} built & deployed to ${DEPLOY}"
        }
        failure {
            echo "❌ FAILED: Check logs above."
        }
    }
}
