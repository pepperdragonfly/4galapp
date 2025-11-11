pipeline {
sshagent(credentials: [env.MASTER_SSH_CRED_ID]) {
sh '''
ssh -o StrictHostKeyChecking=no ${MASTER_HOST} 'hostname && whoami'
'''
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


# Docker 로그인 (세션 범위)
echo "$DH_PASS" | docker login -u pepperdragonfly --password-stdin


# 소스 최신화: 항상 원격 HEAD 기준
mkdir -p ~/app && cd ~/app
if [ ! -d .git ]; then
git clone --depth=1 https://github.com/pepperdragonfly/4galapp.git .
else
git fetch --all --prune
git reset --hard origin/master
fi


# 캐시가 필요 없으면 --no-cache 옵션 잠깐 사용 가능
docker build -t ${REGISTRY_REPO}:${TAG_SHORT} .
docker push ${REGISTRY_REPO}:${TAG_SHORT}


# (선택) latest도 유지하고 싶으면 추가 푸시
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


echo "\n[VERIFY] Deploy & Pods"
kubectl get deploy/${DEPLOY} -n ${NS} -o wide
kubectl get pods -n ${NS} -l app=${DEPLOY} -o wide


echo "\n[VERIFY] Running image digest (per pod)"
kubectl get pods -n ${NS} -l app=${DEPLOY} -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].imageID}{"\n"}{end}'
echo
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
