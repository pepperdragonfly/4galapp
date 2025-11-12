# 최초 또는 구조 바뀐 뒤
\terraform init -upgrade

# 계획
\terraform plan -var="key_name=네_기존_키페어_이름"

# 적용
\terraform apply -auto-approve -var="key_name=네_기존_키페어_이름"

# 출력 확인
\terraform output
