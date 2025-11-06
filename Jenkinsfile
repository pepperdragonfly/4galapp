pipeline {
  agent any
  stages {
    stage('Checkout') {
      steps {
        checkout scm
        echo '✅ 코드 체크아웃 완료'
      }
    }
    stage('Trigger Ansible') {
      steps {
        sshagent(['ansdoc-ssh']) {
          sh '''
          echo "🔹 ansdoc로 배포 트리거"
          ssh -o StrictHostKeyChecking=no ec2-user@10.0.2.171 \
            "ansible-playbook /home/ec2-user/cicd-playbook.yml"
          '''
        }
      }
    }
  }
  post {
    success { echo '🚀 파이프라인 성공' }
    failure { echo '❌ 실패 — 콘솔 로그 확인' }
  }
}
