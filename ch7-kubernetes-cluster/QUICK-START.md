# 쿠버네티스 클러스터 구축 빠른 시작 가이드

## 🚀 개요

이 가이드는 VM 3대(Control Plane 1개, Worker Node 2개)를 사용하여 kubeadm으로 쿠버네티스 클러스터를 구축하는 방법을 설명합니다.

## 📋 사전 요구사항

### 하드웨어 요구사항
- **Control Plane 노드**: 2 CPU, 2GB RAM, 20GB 디스크
- **Worker 노드**: 1 CPU, 1GB RAM, 20GB 디스크

### 소프트웨어 요구사항
- Ubuntu 20.04 LTS 또는 22.04 LTS
- sudo 권한을 가진 사용자 계정
- 인터넷 연결

### 네트워크 요구사항
- 모든 노드 간 네트워크 연결 가능
- 방화벽에서 필요한 포트 개방

## ⚡ 빠른 설치 (권장)

모든 노드에서 다음 단계를 수행하세요:

### 1단계: 스크립트 다운로드
```bash
# 이 리포지토리 클론 (또는 스크립트 파일들 복사)
git clone https://github.com/yourusername/docker-labs-v1.git
cd docker-labs-v1/ch7-kubernetes-cluster/scripts
```

### 2단계: 올인원 설치 스크립트 실행
```bash
# 모든 노드에서 실행
sudo ./setup-all-nodes.sh
```

이 스크립트는 다음 작업을 자동으로 수행합니다:
- ✅ Swap 비활성화
- ✅ containerd 설치 및 설정
- ✅ 필수 커널 모듈 로드
- ✅ sysctl 파라미터 설정
- ✅ kubeadm, kubelet, kubectl 설치

### 3단계: 시스템 재부팅
```bash
sudo reboot
```

## 🎯 클러스터 초기화

### Control Plane 노드에서만 실행

#### 1. 클러스터 초기화
```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

#### 2. kubectl 설정
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 3. 네트워크 플러그인 설치 (Calico)
```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
```

#### 4. Worker 노드 조인 명령어 확인
```bash
kubeadm token create --print-join-command
```

### Worker 노드에서 실행

Control Plane 초기화 완료 후 출력된 join 명령어를 각 Worker 노드에서 실행:
```bash
sudo kubeadm join <CONTROL-PLANE-IP>:6443 --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH>
```

## 🔍 클러스터 상태 확인

### Control Plane에서 확인
```bash
# 노드 상태 확인
kubectl get nodes

# 모든 파드 상태 확인
kubectl get pods --all-namespaces

# 클러스터 정보 확인
kubectl cluster-info
```

## 🐛 수동 설치 (문제 발생시)

올인원 스크립트에 문제가 있을 경우 개별 스크립트를 실행할 수 있습니다:

### 1. 사전 준비 확인
```bash
./check-prerequisites.sh
```

### 2. Swap 비활성화
```bash
./disable-swap.sh
```

### 3. containerd 설치
```bash
./install-containerd.sh
```

### 4. 쿠버네티스 구성 요소 설치
```bash
./install-kubernetes.sh
```

### 5. 시스템 설정
```bash
# 커널 모듈 로드
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl 설정
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

## 🔧 유용한 명령어

### 클러스터 관리
```bash
# 노드 정보 상세 조회
kubectl describe nodes

# 네임스페이스 목록
kubectl get namespaces

# 새로운 조인 토큰 생성
kubeadm token create --print-join-command

# 클러스터 설정 보기
kubectl config view
```

### 문제 해결
```bash
# kubelet 로그 확인
sudo journalctl -xeu kubelet

# containerd 상태 확인
sudo systemctl status containerd

# 파드 로그 확인
kubectl logs <pod-name> -n <namespace>
```

## 📚 추가 정보

### 포트 정보
**Control Plane 노드:**
- 6443: Kubernetes API server
- 2379-2380: etcd server client API
- 10250: Kubelet API
- 10259: kube-scheduler
- 10257: kube-controller-manager

**Worker 노드:**
- 10250: Kubelet API
- 30000-32767: NodePort Services

### 네트워크 플러그인 옵션
- **Calico**: `kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml`
- **Flannel**: `kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml`
- **Weave**: `kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml`

### 클러스터 초기화 옵션
```bash
# 특정 Kubernetes 버전으로 초기화
sudo kubeadm init --kubernetes-version=v1.28.0 --pod-network-cidr=192.168.0.0/16

# Control Plane 엔드포인트 지정
sudo kubeadm init --control-plane-endpoint=<LOAD-BALANCER-DNS>:6443 --pod-network-cidr=192.168.0.0/16

# 설정 파일 사용
sudo kubeadm init --config=kubeadm-config.yaml
```

## ❗ 문제 해결

### 일반적인 문제들

1. **Swap이 활성화되어 있음**
   ```bash
   sudo swapoff -a
   sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
   ```

2. **containerd 서비스 실행 안됨**
   ```bash
   sudo systemctl restart containerd
   sudo systemctl enable containerd
   ```

3. **kubelet 시작 실패**
   ```bash
   sudo systemctl status kubelet
   sudo journalctl -xeu kubelet
   ```

4. **네트워크 플러그인 문제**
   ```bash
   kubectl get pods -n kube-system
   kubectl describe pod <calico-pod-name> -n kube-system
   ```

### 클러스터 리셋 (필요시)
```bash
# 모든 노드에서
sudo kubeadm reset
sudo systemctl stop kubelet
sudo rm -rf /etc/kubernetes/
sudo rm -rf ~/.kube/
sudo rm -rf /var/lib/etcd/

# iptables 규칙 정리
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
```

## 📞 지원

문제가 발생하면 다음을 확인하세요:
1. [공식 쿠버네티스 문서](https://kubernetes.io/docs/)
2. [kubeadm 문제 해결 가이드](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)
3. 각 스크립트의 로그 출력