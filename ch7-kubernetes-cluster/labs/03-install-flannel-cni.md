# Lab 3: Pod 네트워크(CNI) 설치 - Flannel

## 목표
- Flannel CNI 플러그인 설치
- 클러스터 네트워킹 활성화
- 노드를 Ready 상태로 변경

## 사전 요구사항
- Control Plane 노드 초기화 완료
- `kubeadm init --pod-network-cidr=10.244.0.0/16` 실행 완료
- kubectl 설정 완료

**중요**: 이 작업은 **Control Plane 노드에서만** 실행합니다. Worker 노드에서는 별도 작업이 필요 없습니다.

## 1단계: kubectl 설정 확인 및 클러스터 상태 확인

### 1.1 kubectl 설정 확인
kubectl 연결 오류가 발생하면 설정을 다시 해주세요:

```bash
# kubectl 설정 (kubeadm init 후 필수)
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 1.2 노드 상태 확인
```bash
# 현재 노드 상태 (NotReady 상태여야 함)
kubectl get nodes

# 시스템 파드 상태 (coredns가 Pending 상태여야 함)
kubectl get pods -n kube-system
```

### 1.3 네트워크 설정 확인
```bash
# 클러스터 연결 테스트
kubectl cluster-info

# Pod CIDR 확인
kubectl cluster-info dump | grep -m 1 cluster-cidr
```

## 2단계: Flannel CNI 설치 (Control Plane에서만)

### 2.1 Flannel 매니페스트 적용
```bash
# Flannel CNI 플러그인 설치 (Control Plane 노드에서 실행)
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

**참고**: 이 명령어를 Control Plane에서 한 번만 실행하면 클러스터 전체에 Flannel이 배포됩니다.

### 2.2 설치 과정 모니터링
```bash
# Flannel 파드 생성 확인
kubectl get pods -n kube-flannel

# 모든 시스템 파드 상태 확인
kubectl get pods -n kube-system
```

## 3단계: 설치 완료 확인

### 3.1 노드 상태 확인
```bash
# 노드가 Ready 상태가 될 때까지 대기 (1-2분 소요)
kubectl get nodes

# 상세 정보 확인
kubectl get nodes -o wide
```

### 3.2 네트워크 파드 상태 확인
```bash
# Flannel 데몬셋 확인
kubectl get daemonset -n kube-flannel

# Flannel 파드 로그 확인 (필요시)
kubectl logs -n kube-flannel -l app=flannel
```

### 3.3 DNS 서비스 확인
```bash
# coredns 파드가 Running 상태인지 확인
kubectl get pods -n kube-system -l k8s-app=kube-dns

# DNS 서비스 상태 확인
kubectl get svc -n kube-system kube-dns
```

## 4단계: 네트워크 기능 테스트

### 4.1 테스트 파드 생성
```bash
# 간단한 테스트 파드 생성
kubectl run test-pod --image=busybox --restart=Never --rm -it -- /bin/sh
```

테스트 파드 내에서 실행:
```bash
# DNS 해석 테스트
nslookup kubernetes.default.svc.cluster.local

# 외부 네트워크 연결 테스트
ping -c 3 8.8.8.8

# 파드 종료
exit
```

### 4.2 네트워크 인터페이스 확인
```bash
# 호스트의 네트워크 인터페이스 확인
ip addr show flannel.1

# CNI 설정 파일 확인
ls -la /etc/cni/net.d/
```

## 5단계: Worker 노드 자동 설정

**Worker 노드에서는 별도 작업이 필요 없습니다!**

Worker 노드가 클러스터에 조인되면:
- Flannel 데몬셋이 자동으로 각 Worker 노드에 파드 생성
- 네트워크 설정이 자동으로 구성됨

```bash
# Control Plane에서 모든 노드의 Flannel 상태 확인
kubectl get pods -n kube-flannel -o wide

# 조인 명령어는 여전히 Control Plane에서 생성
kubeadm token create --print-join-command
```

## 문제 해결

### 일반적인 문제들

#### kubectl 연결 오류 (localhost:8080 connection refused)
kubectl 설정이 안되어 있는 경우:

```bash
# kubectl 설정 다시 하기
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 연결 확인
kubectl cluster-info
```

#### Flannel 파드가 시작되지 않는 경우
```bash
# Flannel 파드 로그 확인
kubectl logs -n kube-flannel -l app=flannel

# 파드 상세 정보 확인
kubectl describe pods -n kube-flannel -l app=flannel
```

#### 노드가 Ready 상태가 되지 않는 경우
```bash
# 노드 상세 정보 확인
kubectl describe nodes

# kubelet 로그 확인
sudo journalctl -xeu kubelet
```

#### DNS가 작동하지 않는 경우
```bash
# coredns 로그 확인
kubectl logs -n kube-system -l k8s-app=kube-dns

# coredns 설정 확인
kubectl get configmap -n kube-system coredns -o yaml
```

### Flannel 재설치
문제가 계속되면 Flannel을 재설치:

```bash
# Flannel 제거
kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# 잠시 대기 후 재설치
sleep 10
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

## 성공 기준

다음 모든 조건이 만족되면 Flannel 설치가 성공한 것입니다:

1. `kubectl get nodes`에서 모든 노드가 Ready 상태
2. `kubectl get pods -n kube-flannel`에서 모든 Flannel 파드가 Running 상태
3. `kubectl get pods -n kube-system`에서 coredns 파드가 Running 상태
4. 테스트 파드에서 DNS 및 네트워크 연결이 정상 작동

## 다음 단계

Flannel CNI 설치가 완료되면 클러스터가 완전히 준비된 상태입니다. 이제 애플리케이션을 배포할 수 있습니다.

```bash
# 클러스터 상태 최종 확인
kubectl get nodes
kubectl get pods --all-namespaces
kubectl cluster-info
```