############################
# 키페어 자동 생성 (jenkins-key.pem)
############################
resource "tls_private_key" "jenkins" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins" {
  key_name   = "jenkins-key"
  public_key = tls_private_key.jenkins.public_key_openssh
  tags       = { Name = "jenkins-key" }
}

resource "local_sensitive_file" "jenkins_pem" {
  filename        = "/root/jenkins-key.pem"
  content         = tls_private_key.jenkins.private_key_pem
  file_permission = "0600"
}

############################
# AMI (Amazon Linux 2 x86_64)
############################
data "aws_ami" "al2" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################
# EC2용 IAM Role (SSM 접속)
############################
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = { Name = "ec2-ssm-role" }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

############################
# 변수 (EC2만 해당)
############################
variable "key_name" {
  description = "EC2 SSH key pair name (비우면 자동 생성한 jenkins-key 사용)"
  type        = string
  default     = ""
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "root_volume_gb" {
  type    = number
  default = 20
}

############################
# Jenkins 설치 user_data
############################
locals {
  jenkins_user_data = <<-EOT
    #!/bin/bash
    set -eux
    yum update -y
    yum install -y java-11-openjdk wget git
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
    yum install -y jenkins
    systemctl enable jenkins
    systemctl start jenkins
    yum install -y docker
    systemctl enable docker
    systemctl start  docker
    usermod -aG docker jenkins || true
  EOT
}

############################
# Jenkins EC2 (Public Subnet, jenkins-sg)
############################
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.jenkins_instance_type
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm_profile.name
  key_name                    = var.key_name != "" ? var.key_name : aws_key_pair.jenkins.key_name

  user_data = local.jenkins_user_data

  root_block_device {
    volume_size           = var.root_volume_gb
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "company-jenkins" }

  depends_on = [
    aws_key_pair.jenkins,
    local_sensitive_file.jenkins_pem
  ]
}

############################
# 출력
############################
output "jenkins_public_ip" {
  value       = aws_instance.jenkins.public_ip
  description = "접속: http://<이 IP>:8080"
}

output "jenkins_ssh_command" {
  value       = "ssh -i /root/jenkins-key.pem ec2-user@${aws_instance.jenkins.public_ip}"
  description = "SSH 접속 커맨드"
}

output "jenkins_initial_password_hint" {
  value       = "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
  description = "Jenkins 초기 비밀번호 확인 커맨드"
}

