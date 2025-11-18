# Lab 2: Control Plane 노드 초기화

## 목표
- kubeadm init을 사용하여 Control Plane 노드 초기화
- kubectl 설정 및 클러스터 접근 구성
- 네트워크 플러그인 설치

## 사전 요구사항
- [Lab 1: 사전 준비](./01-prerequisite.md) 완료
- Control Plane 노드에서 실행
- sudo 권한을 가진 사용자 계정

## 1단계: 클러스터 초기화 준비

### 1.1 기존 클러스터 확인 및 정리
```bash
# 기존 클러스터가 있는지 확인
kubectl get nodes 2>/dev/null || echo "기존 클러스터 없음"

# 기존 클러스터가 있다면 완전 초기화
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/
sudo rm -rf ~/.kube/
sudo rm -rf /var/lib/etcd
sudo systemctl restart containerd kubelet
```

### 1.2 사전 준비 사항 최종 확인
```bash
# 사전 준비 확인 스크립트 실행
../scripts/check-prerequisites.sh
```

### 1.3 필요한 이미지 미리 다운로드 (선택사항)
```bash
# 클러스터 구성에 필요한 이미지들을 미리 다운로드
sudo kubeadm config images pull
```

## 2단계: kubeadm init 실행

### 2.1 클러스터 초기화
```bash
# Pod 네트워크 CIDR을 지정하여 클러스터 초기화
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

### 2.2 고급 초기화 옵션 (선택사항)

#### 특정 Kubernetes 버전 지정
```bash
sudo kubeadm init --kubernetes-version=v1.28.0 --pod-network-cidr=10.244.0.0/16
```

#### API Server 접근 IP 지정
```bash
sudo kubeadm init --apiserver-advertise-address=<CONTROL_PLANE_IP> --pod-network-cidr=10.244.0.0/16
```

## 3단계: kubectl 설정

### 3.1 kubectl 설정 파일 복사
```bash
# kubectl 설정 디렉토리 생성
mkdir -p $HOME/.kube

# 관리자 설정 파일 복사
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# 파일 소유권 변경
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 3.2 kubectl 동작 확인
```bash
# 클러스터 정보 확인
kubectl cluster-info

# 노드 상태 확인 (현재는 NotReady 상태일 것임)
kubectl get nodes

# 모든 파드 상태 확인
kubectl get pods --all-namespaces
```

## 4단계: Worker 노드 조인 준비

**중요**: 현재 상태에서는 Control Plane 노드가 `NotReady` 상태입니다. 이는 정상이며, CNI(네트워크 플러그인) 설치 후에 `Ready` 상태가 됩니다.

### 4.1 조인 명령어 생성
```bash
# Worker 노드가 클러스터에 조인할 때 사용할 명령어 생성
kubeadm token create --print-join-command
```

이 명령어는 다음과 같은 형태로 출력됩니다:
```bash
sudo kubeadm join <CONTROL-PLANE-IP>:6443 --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH>
```

### 4.2 조인 토큰 및 해시 개별 확인 (참고용)
```bash
# 토큰 목록 확인
kubeadm token list

# CA 인증서 해시 확인
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
```

## 5단계: 클러스터 상태 확인

### 5.1 클러스터 상태 확인
```bash
# 노드 상태 확인
kubectl get nodes

# 시스템 파드 상태 확인
kubectl get pods -n kube-system

# 클러스터 정보 확인
kubectl cluster-info
```

**현재 상태**:
- 노드: `NotReady` (네트워크 플러그인 미설치로 정상)
- coredns 파드: `Pending` 상태 (네트워크 플러그인 설치 후 정상화)

## 6단계: 추가 설정 (선택사항)

### 6.1 bash 자동완성 설정
```bash
# kubectl bash 자동완성 설정
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

# 설정 적용
source ~/.bashrc
```

### 6.2 Control Plane에서 일반 워크로드 실행 허용 (단일 노드 클러스터용)
기본적으로 Control Plane 노드에는 일반 파드가 스케줄되지 않습니다. 단일 노드 테스트 환경에서만 허용:

```bash
# Control Plane 노드의 taint 제거 (선택사항)
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

**주의**: 프로덕션 환경에서는 권장하지 않습니다.

## 7단계: 문제 해결

### 7.1 일반적인 문제들

#### 포트 사용 중 오류 (Port-6443, Port-10259 등)
기존 클러스터가 있을 때 발생합니다. 완전히 초기화 후 재시작:

```bash
# 1. 기존 클러스터 완전 초기화
sudo kubeadm reset -f

# 2. 설정 파일 정리
sudo rm -rf /etc/kubernetes/
sudo rm -rf ~/.kube/

# 3. etcd 데이터 정리
sudo rm -rf /var/lib/etcd

# 4. 컨테이너 런타임 재시작
sudo systemctl restart containerd
sudo systemctl restart kubelet

# 5. 다시 초기화 실행
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

#### kubeadm init 일반적인 실패
```bash
# 로그 확인
sudo journalctl -xeu kubelet

# 기존 설정 정리 후 재시도
sudo kubeadm reset
sudo systemctl restart kubelet
```

#### kubectl 연결 문제
```bash
# 설정 파일 권한 확인
ls -la $HOME/.kube/config

# API 서버 연결 테스트
curl -k https://localhost:6443/version
```

#### 포트 충돌 문제
```bash
# 포트 6443이 사용 중인지 확인
sudo netstat -tlnp | grep :6443

# 필요시 프로세스 종료 후 재시도
```

## 성공 기준

다음 조건이 만족되면 Control Plane 초기화가 성공한 것입니다:

1. `kubeadm init` 명령어가 오류 없이 완료
2. `kubectl cluster-info`가 정상 응답  
3. `kubectl get nodes`에서 Control Plane 노드 표시
4. `kubeadm token create --print-join-command`가 조인 명령어 생성

## 다음 단계

Control Plane 초기화 완료 후 Worker 노드들을 클러스터에 조인시킵니다.