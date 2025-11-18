# 🚀 Kubernetes 클러스터 구축 종합 가이드

> 3개 VM(Control Plane 1개 + Worker 2개)으로 kubeadm을 사용한 Kubernetes 클러스터 완전 구축

## 📋 목차
1. [클러스터 구성 개요](#클러스터-구성-개요)
2. [VM 준비](#vm-준비)
3. [전체 구축 프로세스](#전체-구축-프로세스)
4. [빠른 시작](#빠른-시작)
5. [단계별 상세 가이드](#단계별-상세-가이드)
6. [문제 해결](#문제-해결)
7. [검증 및 테스트](#검증-및-테스트)

---

## 클러스터 구성 개요

### 📊 클러스터 사양
- **Kubernetes 버전**: v1.28.x
- **Container Runtime**: containerd
- **Network Plugin**: Flannel CNI
- **Pod Network CIDR**: 10.244.0.0/16
- **Service CIDR**: 10.96.0.0/12 (기본값)

### 🖥️ 노드 구성
| 역할 | 호스트명 | IP 주소 예시 | 필요 자원 |
|------|----------|--------------|-----------|
| Control Plane | k8s-master | 192.168.1.100 | 2 CPU, 2GB RAM |
| Worker Node 1 | k8s-worker1 | 192.168.1.101 | 1 CPU, 2GB RAM |
| Worker Node 2 | k8s-worker2 | 192.168.1.102 | 1 CPU, 2GB RAM |

---

## VM 준비

### 💻 운영체제 요구사항
- **OS**: Ubuntu 20.04 LTS 또는 22.04 LTS
- **커널**: 3.10+ (권장: 4.15+)
- **아키텍처**: x86_64 (amd64)

### 🔧 기본 시스템 설정
모든 VM에서 다음 사항 확인:
```bash
# 1. 호스트명 설정 (각 노드마다 다르게)
sudo hostnamectl set-hostname k8s-master      # Control Plane
sudo hostnamectl set-hostname k8s-worker1     # Worker 1
sudo hostnamectl set-hostname k8s-worker2     # Worker 2

# 2. /etc/hosts 파일 업데이트 (모든 노드에서 동일)
sudo tee -a /etc/hosts <<EOF
192.168.1.100 k8s-master
192.168.1.101 k8s-worker1
192.168.1.102 k8s-worker2
EOF

# 3. 방화벽 비활성화 (선택적)
sudo ufw disable

# 4. 시간 동기화
sudo apt update
sudo apt install -y ntp
sudo systemctl enable --now ntp
```

### 🔐 SSH 접근 설정
```bash
# SSH 키 기반 접근 설정 (선택적)
ssh-keygen -t rsa -b 4096
ssh-copy-id user@k8s-master
ssh-copy-id user@k8s-worker1
ssh-copy-id user@k8s-worker2
```

---

## 전체 구축 프로세스

### 🎯 구축 순서 (중요!)
```
1. 모든 노드 → 사전 조건 설정
   ├── Swap 비활성화
   ├── containerd 설치/구성
   ├── kubeadm/kubelet/kubectl 설치
   └── 시스템 파라미터 설정

2. Control Plane → 클러스터 초기화
   ├── kubeadm init 실행
   ├── kubectl 설정
   └── 조인 토큰 생성

3. Control Plane → CNI 설치
   └── Flannel 네트워크 설치

4. Worker 노드들 → 클러스터 조인
   ├── Worker 1 조인
   ├── Worker 2 조인
   └── 조인 상태 확인

5. 전체 클러스터 → 검증
   ├── 노드 상태 확인
   ├── 네트워크 테스트
   └── 샘플 애플리케이션 배포
```

### ⏱️ 예상 소요 시간
- **전체 구축**: 20-30분
- **각 노드 사전 조건**: 5-10분
- **Control Plane 초기화**: 3-5분
- **CNI 설치**: 2-3분  
- **Worker 조인 (각각)**: 2-3분

---

## 빠른 시작

### 🚀 자동화 스크립트 사용

#### 1단계: 모든 노드 사전 조건 설정
```bash
# 모든 노드에서 실행
cd ch7-kubernetes-cluster/scripts
sudo ./setup-all-nodes.sh
```

#### 2단계: Control Plane 초기화
```bash
# Control Plane에서만 실행
./init-control-plane.sh
```

#### 3단계: CNI 설치
```bash
# Control Plane에서만 실행
./install-flannel.sh
```

#### 4단계: Worker 노드 조인
```bash
# 각 Worker 노드에서 실행
./join-worker-node.sh "sudo kubeadm join <생성된-조인-명령어>"
```

#### 5단계: 클러스터 검증
```bash
# Control Plane에서 확인
kubectl get nodes
kubectl get pods --all-namespaces
```

### ⚡ 원라이너 명령어 (고급 사용자용)
```bash
# Control Plane 완전 초기화 + CNI 설치
cd ch7-kubernetes-cluster/scripts && \
sudo ./setup-all-nodes.sh && \
./init-control-plane.sh && \
./install-flannel.sh

# Worker 노드 준비
cd ch7-kubernetes-cluster/scripts && \
sudo ./setup-all-nodes.sh
```

---

## 단계별 상세 가이드

### 📚 랩 가이드 링크
각 단계의 자세한 내용은 해당 랩 가이드를 참고하세요:

1. **[01-prerequisite.md](labs/01-prerequisite.md)**
   - Swap 비활성화
   - Container Runtime (containerd) 설치
   - kubeadm/kubelet/kubectl 설치
   - 시스템 설정 및 검증

2. **[02-init-control-plane.md](labs/02-init-control-plane.md)**
   - kubeadm init 실행
   - kubectl 설정
   - 조인 토큰 생성 및 관리

3. **[03-install-flannel-cni.md](labs/03-install-flannel-cni.md)**
   - Flannel CNI 설치
   - 네트워크 정책 설정
   - 연결 테스트

4. **[04-join-worker-nodes.md](labs/04-join-worker-nodes.md)**
   - Worker 노드 조인
   - 네트워크 연결 확인
   - 클러스터 검증

### 🛠️ 사용 가능한 스크립트

| 스크립트 | 설명 | 실행 위치 |
|----------|------|-----------|
| `setup-all-nodes.sh` | 모든 노드 사전 조건 설정 | 모든 노드 |
| `check-prerequisites.sh` | 사전 조건 검증 | 모든 노드 |
| `init-control-plane.sh` | Control Plane 초기화 | Control Plane |
| `install-flannel.sh` | Flannel CNI 설치 | Control Plane |
| `join-worker-node.sh` | Worker 노드 조인 | Worker 노드 |

---

## 문제 해결

### ❗ 일반적인 문제들

#### 1. Swap 관련 오류
```bash
# 오류: [ERROR Swap]: running with swap on is not supported
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

#### 2. Container Runtime 오류
```bash
# containerd 서비스 재시작
sudo systemctl restart containerd
sudo systemctl status containerd
```

#### 3. kubectl 연결 오류
```bash
# kubectl 설정 복사
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 4. 네트워크 연결 문제
```bash
# 방화벽 확인
sudo ufw status
sudo iptables -L

# DNS 해상도 확인
nslookup kubernetes.default.svc.cluster.local
```

#### 5. 노드가 NotReady 상태
```bash
# 노드 상세 정보 확인
kubectl describe node <노드명>

# kubelet 로그 확인
sudo journalctl -u kubelet -f
```

### 🔧 초기화 및 재시작

#### 전체 클러스터 초기화
```bash
# 모든 노드에서 실행
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/
sudo rm -rf ~/.kube/
sudo systemctl restart containerd kubelet
```

#### Control Plane 재초기화
```bash
# Control Plane에서만 실행
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/
sudo rm -rf ~/.kube/
```

---

## 검증 및 테스트

### ✅ 클러스터 상태 확인

#### 1. 노드 상태
```bash
# 모든 노드가 Ready 상태인지 확인
kubectl get nodes

# 상세 정보 확인
kubectl get nodes -o wide
kubectl describe nodes
```

#### 2. 시스템 파드 상태
```bash
# 모든 시스템 파드가 Running 상태인지 확인
kubectl get pods --all-namespaces

# 특정 네임스페이스 확인
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel
```

#### 3. 네트워크 연결 테스트
```bash
# DNS 해상도 테스트
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default

# Pod 간 통신 테스트
kubectl run test-1 --image=nginx
kubectl run test-2 --image=busybox --rm -it -- wget -O- http://test-1
```

### 🧪 샘플 애플리케이션 배포

#### 간단한 웹 애플리케이션 배포
```bash
# nginx 배포
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# 서비스 확인
kubectl get services
kubectl get pods

# 접근 테스트
curl http://<노드IP>:<NodePort>
```

#### 다중 레플리카 애플리케이션 테스트
```bash
# 레플리카 3개로 배포
kubectl create deployment hello-world --image=k8s.gcr.io/echoserver:1.4 --replicas=3
kubectl expose deployment hello-world --port=8080 --type=NodePort

# Pod 분산 확인
kubectl get pods -o wide
```

### 📊 클러스터 정보 수집

#### 종합 상태 보고서 생성
```bash
#!/bin/bash
echo "=== Kubernetes 클러스터 상태 보고서 ==="
echo "생성 시간: $(date)"
echo ""

echo "=== 클러스터 정보 ==="
kubectl cluster-info

echo ""
echo "=== 노드 상태 ==="
kubectl get nodes -o wide

echo ""
echo "=== 시스템 파드 ==="
kubectl get pods --all-namespaces

echo ""
echo "=== 서비스 ==="
kubectl get services --all-namespaces

echo ""
echo "=== 네트워크 정책 ==="
kubectl get networkpolicy --all-namespaces 2>/dev/null || echo "네트워크 정책 없음"

echo ""
echo "=== 스토리지 클래스 ==="
kubectl get storageclass

echo ""
echo "=== 이벤트 (최근 10개) ==="
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10
```

---

## 🎓 추가 학습 리소스

### 📖 권장 다음 단계
1. **애플리케이션 배포**
   - Deployment, Service, Ingress 학습
   - ConfigMap, Secret 사용법

2. **모니터링 설정**
   - Prometheus + Grafana 설치
   - 클러스터 메트릭 수집

3. **로그 관리**
   - ELK Stack 또는 Fluentd 설정
   - 중앙집중식 로깅

4. **보안 강화**
   - RBAC 설정
   - 네트워크 정책 구성
   - Pod Security Standards

5. **고가용성**
   - Multi-master 클러스터 구성
   - etcd 백업/복원

### 🔗 유용한 명령어 모음
```bash
# 클러스터 정보
kubectl cluster-info
kubectl api-resources
kubectl api-versions

# 리소스 관리
kubectl get all --all-namespaces
kubectl top nodes
kubectl top pods --all-namespaces

# 문제 해결
kubectl logs <pod-name>
kubectl describe <resource-type> <resource-name>
kubectl events --sort-by=.metadata.creationTimestamp

# 설정 관리
kubectl config view
kubectl config current-context
kubectl config get-contexts
```

---

## 📞 지원 및 문의

### 🐛 버그 리포트
문제가 발생하면 다음 정보를 포함하여 리포트해주세요:
- OS 버전 및 커널 정보
- Kubernetes 및 관련 도구 버전
- 오류 로그 및 증상
- 재현 단계

### 📚 추가 문서
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [kubeadm 설치 가이드](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Flannel CNI 문서](https://github.com/flannel-io/flannel)

---

**🎉 축하합니다! 이제 완전한 Kubernetes 클러스터를 구축할 수 있습니다!**

> ⚠️ **참고**: 이 가이드는 학습 및 개발 환경용입니다. 프로덕션 환경에서는 추가적인 보안 및 고가용성 설정이 필요합니다.