pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        REGISTRY_REPO = 'pepperdragonfly/4glapp'
        ANSDOC_HOST   = 'yes25@10.0.2.171'
        MASTER_HOST   = 'yes25@10.0.2.213'
        NS            = 'default'
        DEPLOY        = 'webapp'

        GITHUB_SSH_CRED_ID = 'github-ssh'
        ANSDOC_SSH_CRED_ID = 'yes25'
        MASTER_SSH_CRED_ID = 'yes25'
        DOCKERHUB_PASS_ID  = 'dockerhub-pass'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.TAG_SHORT = env.GIT_COMMIT?.take(7) ?: sh(
                        returnStdout: true,
                        script: "git rev-parse --short=7 HEAD"
                    ).trim()
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

        stage('Build & Push (ansdoc)') {
            steps {
                sshagent(credentials: [env.ANSDOC_SSH_CRED_ID]) {
                    withCredentials([string(credentialsId: env.DOCKERHUB_PASS_ID, variable: 'DH_PASS')]) {
                        sh '''
                            set -euo pipefail
                            ssh -T -o StrictHostKeyChecking=no ${ANSDOC_HOST} <<'REMOTE'
                            set -euo pipefail

                            echo "$DH_PASS" | docker login -u pepperdragonfly --password-stdin

                            mkdir -p ~/app && cd ~/app
                            if [ ! -d .git ]; then
                                git clone --depth=1 https://github.com/pepperdragonfly/4galapp.git .
                            else
                                git fetch --all --prune
                                git reset --hard origin/master
                            fi

                            docker build -t ${REGISTRY_REPO}:${TAG_SHORT} .
                            docker push ${REGISTRY_REPO}:${TAG_SHORT}
                            docker tag ${REGISTRY_REPO}:${TAG_SHORT} ${REGISTRY_REPO}:latest
                            docker push ${REGISTRY_REPO}:latest
                            docker logout || true
                            REMOTE
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
                        ssh -T -o StrictHostKeyChecking=no ${MASTER_HOST} <<REMOTE
                        set -euo pipefail

                        echo "Rolling update to ${REGISTRY_REPO}:${TAG_SHORT} ..."
                        kubectl set image deployment/${DEPLOY} ${DEPLOY}=${REGISTRY_REPO}:${TAG_SHORT} -n ${NS}
                        kubectl rollout status deployment/${DEPLOY} -n ${NS} --timeout=180s
                        kubectl annotate deployment/${DEPLOY} -n ${NS} kubernetes.io/change-cause="Set ${DEPLOY} image to ${REGISTRY_REPO}:${TAG_SHORT}" --overwrite

                        kubectl get deploy/${DEPLOY} -n ${NS} -o wide
                        kubectl get pods -n ${NS} -l app=${DEPLOY} -o wide
                        kubectl get pods -n ${NS} -l app=${DEPLOY} -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.status.containerStatuses[0].imageID}{"\\n"}{end}'
                        REMOTE
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
