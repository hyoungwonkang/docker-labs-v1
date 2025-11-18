# Lab 1: 쿠버네티스 클러스터 구축을 위한 사전 준비

## 목표
- 모든 노드에서 swap 비활성화
- containerd(Container Runtime) 설치 확인
- 네트워크 및 시스템 설정 확인

## 사전 요구사항
- Ubuntu 20.04 LTS 또는 22.04 LTS
- sudo 권한을 가진 사용자 계정
- 인터넷 연결

## 1단계: Swap 비활성화

쿠버네티스는 성능상의 이유로 swap을 비활성화할 것을 요구합니다.

### 1.1 현재 swap 상태 확인
```bash
# swap 사용 현황 확인
free -h
swapon --show
```

### 1.2 임시로 swap 비활성화
```bash
# 현재 세션에서 swap 비활성화
sudo swapoff -a
```

### 1.3 영구적으로 swap 비활성화
```bash
# /etc/fstab에서 swap 라인을 주석 처리
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### 1.4 확인
```bash
# swap이 비활성화되었는지 확인
free -h
```

## 2단계: containerd 설치 확인

### 2.1 containerd 설치 여부 확인
```bash
# containerd 서비스 상태 확인
sudo systemctl status containerd

# containerd 버전 확인
containerd --version
```

### 2.2 containerd가 설치되지 않은 경우 설치
```bash
# 패키지 업데이트
sudo apt update

# 필수 패키지 설치
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Docker의 공식 GPG 키 추가
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Docker 리포지토리 추가
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 패키지 목록 업데이트
sudo apt update

# containerd 설치
sudo apt install -y containerd.io
```

### 2.3 containerd 설정
```bash
# containerd 기본 설정 생성
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# SystemdCgroup 사용 설정 (쿠버네티스 권장)
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup = true/g' /etc/containerd/config.toml
```

### 2.4 containerd 서비스 시작 및 활성화
```bash
# containerd 서비스 재시작
sudo systemctl restart containerd

# 부팅 시 자동 시작 설정
sudo systemctl enable containerd

# 상태 확인
sudo systemctl status containerd
```

## 3단계: 시스템 설정 확인

### 3.1 필수 커널 모듈 로드
```bash
# 필수 모듈 설정
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# 모듈 로드
sudo modprobe overlay
sudo modprobe br_netfilter
```

### 3.2 sysctl 파라미터 설정
```bash
# 쿠버네티스에 필요한 sysctl 파라미터 설정
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# 설정 적용
sudo sysctl --system
```

## 4단계: 방화벽 설정 (선택사항)

### 4.1 필요한 포트 확인
**Control Plane 노드:**
- 6443: Kubernetes API server
- 2379-2380: etcd server client API
- 10250: Kubelet API
- 10259: kube-scheduler
- 10257: kube-controller-manager

**Worker 노드:**
- 10250: Kubelet API
- 30000-32767: NodePort Services

### 4.2 ufw 사용 시 포트 개방 예시
```bash
# Control Plane 노드에서 실행
sudo ufw allow 6443/tcp
sudo ufw allow 2379:2380/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 10259/tcp
sudo ufw allow 10257/tcp

# Worker 노드에서 실행
sudo ufw allow 10250/tcp
sudo ufw allow 30000:32767/tcp
```

## 확인 스크립트 실행

사전 준비가 완료되었는지 확인하려면 다음 스크립트를 실행하세요:

```bash
# 스크립트에 실행 권한 부여
chmod +x ../scripts/check-prerequisites.sh

# 사전 준비 사항 확인 실행
../scripts/check-prerequisites.sh
```

## 다음 단계

사전 준비가 완료되면 [kubeadm, kubelet, kubectl 설치](./02-install-kubernetes.md)로 진행합니다.