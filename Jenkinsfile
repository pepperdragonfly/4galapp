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
        sh '''
        echo "🔹 ansdoc(yes25ansdoc)로 배포 트리거"
        ssh yes25ansdoc "ansible-playbook /home/ec2-user/cicd-playbook.yml"
        '''
      }
    }
  }

  post {
    success { echo '🚀 파이프라인 성공 — Jenkins → Ansible 연동 완료' }
    failure { echo '❌ 실패 — 콘솔 로그 확인 필요' }
  }
}
