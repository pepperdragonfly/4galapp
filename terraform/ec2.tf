########################################
# ec2.tf — Jenkins EC2 (Amazon Linux 2)
# - 기존 AWS Key Pair만 사용(새 pem 생성 없음)
# - Java 17 + Jenkins(LTS) + Maven + Docker
# - 최신 Jenkins GPG 키(2023) 사용
########################################

# ---- 변수 ----
variable "key_name" {
  type        = string
  description = "기존 AWS 키페어 이름 (콘솔에 이미 등록된 Key Pair)"
  # 예: "yes25-key"  (반드시 실제 존재하는 키 이름 사용)
  validation {
    condition     = length(var.key_name) > 0
    error_message = "key_name을 반드시 설정하세요. 예: -var=\"key_name=yes25-key\""
  }
}

# ---- AMI ----
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ---- Jenkins 설치 스크립트 (Java17 + 최신 GPG) ----
locals {
  jenkins_user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    # 0) 기본 업데이트
    yum update -y

    # 1) 필수 패키지 + Java 17 (Jenkins LTS 최소 요건)
    yum install -y java-17-amazon-corretto-headless wget git maven docker

    # 2) Jenkins repo & 최신 GPG 키(2023) 등록 후 설치
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    yum clean metadata
    yum install -y jenkins

    # 3) Jenkins 0.0.0.0:8080 바인딩 보정
    if ! grep -q '^JENKINS_LISTEN_ADDRESS=' /etc/sysconfig/jenkins 2>/dev/null; then
      echo 'JENKINS_LISTEN_ADDRESS="0.0.0.0"' >> /etc/sysconfig/jenkins
    else
      sed -i 's|^JENKINS_LISTEN_ADDRESS=.*|JENKINS_LISTEN_ADDRESS="0.0.0.0"|' /etc/sysconfig/jenkins
    fi
    sed -i 's/^JENKINS_PORT=.*/JENKINS_PORT="8080"/' /etc/sysconfig/jenkins || true

    # 4) 디렉터리/권한 보정
    mkdir -p /var/{lib,log,cache}/jenkins /var/run/jenkins
    chown -R jenkins:jenkins /var/{lib,log,cache}/jenkins /var/run/jenkins || true
    rm -f /var/run/jenkins/jenkins.pid || true

    # 5) Docker + Jenkins 서비스 기동
    systemctl enable docker
    systemctl start docker
    usermod -aG docker jenkins || true

    systemctl daemon-reload
    systemctl enable jenkins
    systemctl start jenkins
  EOT
}

# ---- Jenkins EC2 ----
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.al2.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.public_a.id                 # main.tf에서 생성됨
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins.id]        # main.tf에서 생성됨
  key_name                    = var.key_name
  user_data                   = local.jenkins_user_data

  tags = merge(local.tags, { Name = "jenkins-server" })
}

# ---- 출력 ----
output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "jenkins_ssh_command" {
  value = "ssh -i </path/to/${var.key_name}.pem> ec2-user@${aws_instance.jenkins.public_ip}"
}

output "jenkins_initial_password_hint" {
  value = "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}

