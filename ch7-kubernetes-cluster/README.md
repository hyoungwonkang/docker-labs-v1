# Chapter 7: Kubernetes 클러스터 구축

> kubeadm을 사용한 Kubernetes 클러스터 구축 실습

## 🎯 학습 목표
- kubeadm을 사용하여 Kubernetes 클러스터 구축
- Control Plane과 Worker Node 구성 이해
- Container Network Interface (CNI) 설정
- 클러스터 상태 확인 및 관리

## 🏗️ 클러스터 환경
- **VM 구성**: 3대 (Control Plane 1개 + Worker Node 2개)
- **OS**: Ubuntu 20.04 LTS 또는 22.04 LTS
- **Container Runtime**: containerd
- **Network Plugin**: Flannel CNI
- **Kubernetes**: v1.28.x

## 📚 실습 구성

### 📖 종합 가이드
**[🚀 COMPLETE-GUIDE.md](COMPLETE-GUIDE.md)** - 전체 프로세스 종합 가이드 (빠른 시작용)

### 📝 단계별 랩 가이드
1. **[사전 조건 설정](labs/01-prerequisite.md)** - 모든 노드 기본 설정
2. **[Control Plane 초기화](labs/02-init-control-plane.md)** - 클러스터 마스터 노드 구성
3. **[Flannel CNI 설치](labs/03-install-flannel-cni.md)** - Pod 네트워크 구성
4. **[Worker 노드 조인](labs/04-join-worker-nodes.md)** - 워커 노드 클러스터 참여

## 🛠️ 자동화 스크립트

### 📋 스크립트 목록
| 스크립트 | 설명 | 실행 위치 | 기능 |
|----------|------|-----------|------|
| `setup-all-nodes.sh` | 모든 노드 사전 조건 자동 설정 | 모든 노드 | swap 비활성화, containerd 설치, kubeadm 설치 |
| `check-prerequisites.sh` | 사전 조건 검증 | 모든 노드 | 설치 상태 및 설정 확인 |
| `init-control-plane.sh` | Control Plane 자동 초기화 | Control Plane | kubeadm init, kubectl 설정 |
| `install-flannel.sh` | Flannel CNI 자동 설치 | Control Plane | Pod 네트워크 구성 |
| `join-worker-node.sh` | Worker 노드 조인 자동화 | Worker 노드 | 대화형/자동 클러스터 조인 |

### 🚀 스크립트 사용법
```bash
# 모든 노드에서 사전 조건 설정
sudo ./scripts/setup-all-nodes.sh

# Control Plane 초기화 (Control Plane에서만)
./scripts/init-control-plane.sh

# CNI 설치 (Control Plane에서만)
./scripts/install-flannel.sh

# Worker 노드 조인 (각 Worker 노드에서)
./scripts/join-worker-node.sh

# 사전 조건 확인 (모든 노드에서)
./scripts/check-prerequisites.sh
```

## ⚡ 빠른 시작

### 🎮 완전 자동화 (권장)
```bash
# 1. Control Plane 완전 구성
cd ch7-kubernetes-cluster/scripts
sudo ./setup-all-nodes.sh && ./init-control-plane.sh && ./install-flannel.sh

# 2. 각 Worker 노드에서
sudo ./setup-all-nodes.sh
./join-worker-node.sh  # 대화형 모드로 조인 명령어 입력

# 3. Control Plane에서 확인
kubectl get nodes
kubectl get pods --all-namespaces
```

### 🔧 수동 단계별 구성
```bash
# Control Plane에서:
sudo ./scripts/setup-all-nodes.sh
./scripts/init-control-plane.sh
./scripts/install-flannel.sh

# Worker Node에서:
sudo ./scripts/setup-all-nodes.sh
sudo kubeadm join <control-plane-ip>:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

## 📋 검증 및 테스트

### ✅ 클러스터 상태 확인
```bash
# 노드 상태 확인
kubectl get nodes -o wide

# 모든 시스템 파드 확인
kubectl get pods --all-namespaces

# 클러스터 정보
kubectl cluster-info

# Flannel 파드 확인
kubectl get pods -n kube-flannel
```

### 🧪 네트워크 테스트
```bash
# DNS 해상도 테스트
kubectl run test-dns --image=busybox --rm -it -- nslookup kubernetes.default

# Pod 간 통신 테스트
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services
```

### 📊 종합 상태 보고서
```bash
# 자동 상태 점검 스크립트 실행
./scripts/check-prerequisites.sh

# 수동 확인 명령어들
kubectl top nodes                    # 노드 리소스 사용량
kubectl get events --sort-by=.metadata.creationTimestamp  # 최근 이벤트
kubectl api-resources               # 사용 가능한 API 리소스
```

## 🔧 문제 해결

### ⚠️ 일반적인 문제들
1. **Swap 오류**: `sudo swapoff -a && sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab`
2. **Container Runtime 오류**: `sudo systemctl restart containerd`
3. **kubectl 연결 오류**: `mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config`
4. **네트워크 문제**: 방화벽 및 CNI 설정 확인
5. **포트 충돌**: `sudo kubeadm reset` 후 재시작

### 🔄 완전 초기화
```bash
# 모든 노드에서 실행 (클러스터 완전 재구축 시)
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/ ~/.kube/
sudo systemctl restart containerd kubelet
```

### 🔍 로그 확인
```bash
# 시스템 서비스 로그
sudo journalctl -u kubelet -f
sudo journalctl -u containerd -f

# Pod 로그 확인
kubectl logs -n kube-system <pod-name>
kubectl describe node <node-name>
```

## 📖 학습 리소스

### 📚 공식 문서
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [kubeadm 설치 가이드](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Flannel CNI 문서](https://github.com/flannel-io/flannel)

### 🎓 추천 다음 단계
1. **애플리케이션 배포**: Deployment, Service, ConfigMap 학습
2. **모니터링 설정**: Prometheus + Grafana 설치
3. **로그 관리**: 중앙집중식 로깅 시스템 구축
4. **보안 강화**: RBAC, 네트워크 정책 설정
5. **고가용성**: Multi-master 클러스터 구성

---

**🎉 성공!** 이제 완전한 3-노드 Kubernetes 클러스터를 구축할 수 있습니다!