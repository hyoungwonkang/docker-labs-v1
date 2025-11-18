# Lab 4: Worker 노드 클러스터 조인

## 목표
- Worker 노드를 쿠버네티스 클러스터에 조인
- 클러스터 확장 및 워크로드 분산 준비
- 모든 노드가 Ready 상태가 되도록 설정

## 사전 요구사항
- Control Plane 노드 초기화 완료
- Worker 노드에 사전 준비 작업 완료 (swap 비활성화, containerd, kubeadm 설치)
- Control Plane에서 생성된 join 명령어 확보

## 1단계: Control Plane에서 Join 명령어 생성

### 1.1 Join 명령어 생성 (Control Plane에서)
```bash
# Worker 노드 조인 명령어 생성
kubeadm token create --print-join-command
```

출력 예시:
```bash
sudo kubeadm join 192.168.1.100:6443 --token abc123.def456ghi789 \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### 1.2 토큰 정보 확인 (참고용)
```bash
# 현재 토큰 목록 확인
kubeadm token list

# 토큰이 만료된 경우 새로 생성
kubeadm token create

# CA 인증서 해시 확인 (필요시)
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
```

## 2단계: Worker 노드 사전 확인

### 2.1 Worker 노드 상태 확인
Worker 노드에서 다음 사항들을 확인:

```bash
# Swap 비활성화 확인
free -h
swapon --show

# containerd 실행 확인
sudo systemctl status containerd

# kubeadm 설치 확인
kubeadm version

# 기존 클러스터 설정이 있는지 확인
ls -la /etc/kubernetes/
```

### 2.2 기존 설정 정리 (필요시)
기존에 클러스터에 조인된 적이 있다면:

```bash
# 기존 설정 초기화
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/
sudo systemctl restart containerd kubelet
```

## 3단계: Worker 노드에서 클러스터 조인

### 3.1 네트워크 연결 확인
```bash
# Control Plane IP로 연결 테스트 (포트 6443)
telnet <CONTROL_PLANE_IP> 6443

# 또는 nc로 확인
nc -zv <CONTROL_PLANE_IP> 6443

# ping 테스트
ping -c 3 <CONTROL_PLANE_IP>
```

### 3.2 Join 명령어 실행
Control Plane에서 생성된 명령어를 Worker 노드에서 실행:

```bash
# Control Plane에서 복사한 join 명령어 실행
sudo kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH>
```

**예시:**
```bash
sudo kubeadm join 192.168.1.100:6443 --token abc123.def456ghi789 \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### 3.3 조인 과정 확인

#### 왜 kubelet 상태를 확인하나요?
kubelet은 Worker 노드와 Control Plane 간의 **핵심 통신 담당자**입니다:
- 🔗 Control Plane API 서버와 연결 상태 관리
- 📋 노드를 클러스터에 등록하고 상태 보고
- 🐳 Pod 생성 및 관리 담당
- ❗ 조인 실패 시 가장 먼저 문제가 나타나는 서비스

```bash
# kubelet 서비스 상태 확인
sudo systemctl status kubelet

# 정상 조인 시 예상 출력:
# ● kubelet.service - kubelet: The Kubernetes Node Agent
#    Loaded: loaded (/lib/systemd/system/kubelet.service; enabled)
#    Active: active (running) since ...
#    Main PID: 1234 (kubelet)

# kubelet 로그 확인 (문제 발생 시)
sudo journalctl -xeu kubelet

# 실시간 로그 모니터링
sudo journalctl -u kubelet -f
```

#### 일반적인 kubelet 문제와 해결방법
```bash
# 1. kubelet이 계속 재시작되는 경우
# 원인: Control Plane 연결 실패, 설정 문제
sudo systemctl status kubelet | grep "activating (auto-restart)"

# 2. 특정 오류 메시지 확인
sudo journalctl -u kubelet | grep -i error

# 3. 설정 파일 확인
ls -la /etc/kubernetes/kubelet.conf  # 조인 후 생성되어야 함
```

## 4단계: Control Plane에서 조인 확인

### 4.1 노드 추가 확인 (Control Plane에서)
```bash
# 모든 노드 상태 확인
kubectl get nodes

# 상세 정보 확인
kubectl get nodes -o wide

# 노드별 상세 정보
kubectl describe nodes
```

### 4.2 Flannel 파드 배포 확인
Flannel CNI가 설치되어 있다면 자동으로 Worker 노드에도 배포됩니다:

```bash
# 모든 노드의 Flannel 파드 확인
kubectl get pods -n kube-flannel -o wide

# 데몬셋 상태 확인
kubectl get daemonset -n kube-flannel
```

## 5단계: 클러스터 상태 최종 확인

### 5.1 모든 노드 Ready 상태 확인
```bash
# 모든 노드가 Ready 상태인지 확인
kubectl get nodes

# 시스템 파드 상태 확인
kubectl get pods --all-namespaces -o wide

# 클러스터 정보 확인
kubectl cluster-info
```

### 5.2 워크로드 배포 테스트
```bash
# 간단한 nginx 파드 배포 테스트
kubectl run nginx-test --image=nginx --port=80

# 파드가 Worker 노드에 스케줄되는지 확인
kubectl get pods -o wide

# 테스트 완료 후 정리
kubectl delete pod nginx-test
```

## 6단계: 추가 Worker 노드 조인 (필요시)

동일한 과정을 반복하여 추가 Worker 노드들을 조인:

1. Control Plane에서 join 명령어 생성 (토큰은 재사용 가능)
2. 추가 Worker 노드에서 사전 준비 확인
3. join 명령어 실행
4. Control Plane에서 노드 추가 확인

```bash
# 동일한 토큰으로 여러 노드 조인 가능 (24시간 유효)
sudo kubeadm join <CONTROL_PLANE_IP>:6443 --token <SAME_TOKEN> \
    --discovery-token-ca-cert-hash sha256:<SAME_HASH>
```

## 문제 해결

### 일반적인 문제들

#### Join 실패 - 네트워크 연결 문제
```bash
# 방화벽 확인
sudo ufw status

# 필요한 포트 개방 (Control Plane)
sudo ufw allow 6443/tcp   # API Server
sudo ufw allow 2379:2380/tcp  # etcd

# 필요한 포트 개방 (Worker Node)
sudo ufw allow 10250/tcp  # kubelet API
sudo ufw allow 30000:32767/tcp  # NodePort Services
```

#### Join 실패 - 토큰 만료
```bash
# Control Plane에서 새 토큰 생성
kubeadm token create --print-join-command

# 또는 기존 토큰 확인
kubeadm token list
```

#### Join 실패 - 인증서 문제
```bash
# CA 해시 다시 확인 (Control Plane에서)
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
```

#### 노드가 NotReady 상태
```bash
# kubelet 상태 확인
sudo systemctl status kubelet

# CNI 플러그인 확인 (Control Plane에서)
kubectl get pods -n kube-flannel

# 노드 상세 정보 확인
kubectl describe node <WORKER_NODE_NAME>
```

### Worker 노드 제거 (필요시)
```bash
# Control Plane에서 노드 제거
kubectl drain <WORKER_NODE_NAME> --ignore-daemonsets --delete-emptydir-data
kubectl delete node <WORKER_NODE_NAME>

# Worker 노드에서 설정 초기화
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/
```

## 성공 기준

다음 모든 조건이 만족되면 Worker 노드 조인이 성공한 것입니다:

1. `kubectl get nodes`에서 모든 노드가 Ready 상태
2. Worker 노드에 Flannel 파드가 Running 상태
3. 테스트 파드가 Worker 노드에 정상 스케줄링
4. `kubectl get pods --all-namespaces`에서 모든 시스템 파드가 정상

## 다음 단계

모든 Worker 노드 조인이 완료되면 쿠버네티스 클러스터 구축이 완료됩니다. 이제 다양한 애플리케이션을 배포하고 운영할 수 있습니다.

```bash
# 최종 클러스터 상태 확인
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl cluster-info
```