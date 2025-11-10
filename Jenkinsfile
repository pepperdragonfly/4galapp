pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-cred') // Jenkins에 등록한 DockerHub 자격증명 ID
        DOCKERHUB_REPO = "4glapp"
        IMAGE_NAME = "yes25-webapp"
        GIT_REPO = "git@github.com:pepperdragonfly/4galapp.git"
        DEPLOY_USER = "yes25"
        DEPLOY_HOST = "yes25ansdoc"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: "${GIT_REPO}", credentialsId: 'github-ssh'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build -t ${DOCKERHUB_REPO}/${IMAGE_NAME}:latest .
                """
            }
        }

        stage('Push to DockerHub') {
            steps {
                sh """
                    echo "${DOCKERHUB_CREDENTIALS_PSW}" | docker login -u "${DOCKERHUB_CREDENTIALS_USR}" --password-stdin
                    docker push ${DOCKERHUB_REPO}/${IMAGE_NAME}:latest
                    docker logout
                """
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sshagent(['yes25-ssh']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${DEPLOY_HOST} '
                            kubectl set image deployment/yes25-webapp yes25-webapp=${DOCKERHUB_REPO}/${IMAGE_NAME}:latest --record
                            kubectl rollout status deployment/yes25-webapp
                        '
                    """
                }
            }
        }
    }

    post {
        success {
            echo "✅ CI/CD pipeline completed successfully."
        }
        failure {
            echo "❌ Pipeline failed. Check logs."
        }
    }
}

