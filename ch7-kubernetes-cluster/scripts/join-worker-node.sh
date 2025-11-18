#!/bin/bash

# Worker 노드 클러스터 조인 스크립트
# 작성자: Kubernetes Lab
# 버전: 1.0

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}$1${NC}"
}

# 사용법
usage() {
    echo "Worker 노드 클러스터 조인 스크립트"
    echo ""
    echo "사용법:"
    echo "  방법 1: 조인 명령어 전체 제공"
    echo "    $0 \"sudo kubeadm join <IP>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>\""
    echo ""
    echo "  방법 2: 대화형 모드"
    echo "    $0"
    echo ""
    echo "예시:"
    echo "  $0 \"sudo kubeadm join 192.168.1.100:6443 --token abc123.def456 --discovery-token-ca-cert-hash sha256:abc123...\""
}

# 스크립트 시작
clear
log_header "========================================"
log_header "     Worker 노드 클러스터 조인"
log_header "========================================"
echo ""

# 1. 사전 확인
log_header "1단계: 사전 확인"
log_header "========================================"

# 현재 노드 정보
current_hostname=$(hostname)
current_ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "확인 불가")
log_info "현재 Worker 노드: $current_hostname ($current_ip)"

# Swap 확인
if [ $(swapon --show | wc -l) -ne 0 ]; then
    log_error "Swap이 활성화되어 있습니다. 비활성화 후 재시도하세요."
    echo "명령어: sudo swapoff -a"
    exit 1
else
    log_success "✓ Swap이 비활성화되어 있습니다."
fi

# containerd 확인
if systemctl is-active --quiet containerd; then
    log_success "✓ containerd가 실행 중입니다."
else
    log_error "containerd가 실행되고 있지 않습니다."
    echo "명령어: sudo systemctl start containerd"
    exit 1
fi

# kubeadm 확인
if command -v kubeadm &> /dev/null; then
    log_success "✓ kubeadm이 설치되어 있습니다."
    echo "   버전: $(kubeadm version -o short)"
else
    log_error "kubeadm이 설치되어 있지 않습니다."
    exit 1
fi

# 기존 클러스터 설정 확인
if [ -f /etc/kubernetes/kubelet.conf ]; then
    log_warning "이 노드는 이미 클러스터에 조인되어 있는 것 같습니다."
    while true; do
        read -p "기존 설정을 초기화하고 새로 조인하시겠습니까? (y/n): " yn
        case $yn in
            [Yy]* ) 
                log_info "기존 설정을 초기화합니다..."
                sudo kubeadm reset -f
                sudo rm -rf /etc/kubernetes/
                sudo systemctl restart containerd kubelet
                break
                ;;
            [Nn]* ) 
                log_error "기존 설정이 있으므로 조인을 중단합니다."
                exit 1
                ;;
            * ) 
                echo "y 또는 n을 입력해주세요."
                ;;
        esac
    done
fi

echo ""

# 2. 조인 정보 수집
log_header "2단계: 조인 정보 수집"
log_header "========================================"

# 명령행 인수 확인
if [ $# -eq 1 ] && [[ "$1" == sudo\ kubeadm\ join* ]]; then
    JOIN_COMMAND="$1"
    log_info "조인 명령어가 제공되었습니다."
else
    # 대화형 모드
    log_info "Control Plane에서 생성된 조인 명령어를 입력해주세요."
    echo ""
    echo "Control Plane에서 다음 명령어로 생성:"
    echo "  kubeadm token create --print-join-command"
    echo ""
    read -p "조인 명령어 입력: " JOIN_COMMAND
fi

# 조인 명령어 검증
if [[ ! "$JOIN_COMMAND" =~ ^sudo\ kubeadm\ join ]]; then
    log_error "올바른 kubeadm join 명령어가 아닙니다."
    echo "형식: sudo kubeadm join <IP>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
    exit 1
fi

# 조인 정보 추출
CONTROL_PLANE_ENDPOINT=$(echo "$JOIN_COMMAND" | grep -oP 'join \K[^:]+:\d+')
CONTROL_PLANE_IP=$(echo "$CONTROL_PLANE_ENDPOINT" | cut -d: -f1)
API_PORT=$(echo "$CONTROL_PLANE_ENDPOINT" | cut -d: -f2)

log_info "조인 정보 확인:"
echo "   Control Plane: $CONTROL_PLANE_IP:$API_PORT"
echo "   토큰: $(echo "$JOIN_COMMAND" | grep -oP 'token \K\S+')"

echo ""

# 3. 네트워크 연결 테스트
log_header "3단계: 네트워크 연결 테스트"
log_header "========================================"

log_info "Control Plane 연결을 테스트합니다..."

# ping 테스트
if ping -c 3 -W 5 "$CONTROL_PLANE_IP" >/dev/null 2>&1; then
    log_success "✓ Control Plane으로 ping 연결 성공"
else
    log_warning "Control Plane으로 ping 실패 (방화벽 설정일 수 있음)"
fi

# 포트 연결 테스트
if timeout 10 bash -c "echo >/dev/tcp/$CONTROL_PLANE_IP/$API_PORT" 2>/dev/null; then
    log_success "✓ Control Plane API 서버($API_PORT)에 연결 가능"
else
    log_error "Control Plane API 서버에 연결할 수 없습니다."
    echo ""
    echo "확인 사항:"
    echo "1. Control Plane IP 주소: $CONTROL_PLANE_IP"
    echo "2. 네트워크 연결 상태"
    echo "3. 방화벽 설정 (포트 $API_PORT 개방 필요)"
    exit 1
fi

echo ""

# 4. 클러스터 조인 실행
log_header "4단계: 클러스터 조인 실행"
log_header "========================================"

log_info "실행할 조인 명령어:"
echo "   $JOIN_COMMAND"
echo ""

while true; do
    read -p "클러스터 조인을 시작하시겠습니까? (y/n): " yn
    case $yn in
        [Yy]* ) 
            break
            ;;
        [Nn]* ) 
            log_info "클러스터 조인을 취소했습니다."
            exit 0
            ;;
        * ) 
            echo "y 또는 n을 입력해주세요."
            ;;
    esac
done

log_info "클러스터 조인을 시작합니다..."
echo ""

# kubeadm join 실행
if eval "$JOIN_COMMAND"; then
    log_success "클러스터 조인이 완료되었습니다!"
else
    log_error "클러스터 조인에 실패했습니다."
    echo ""
    log_info "문제 해결 방법:"
    echo "1. kubelet 로그 확인: sudo journalctl -xeu kubelet"
    echo "2. 네트워크 연결 확인"
    echo "3. 토큰 만료 여부 확인 (Control Plane에서 새 토큰 생성)"
    echo "4. 설정 초기화 후 재시도: sudo kubeadm reset"
    exit 1
fi

echo ""

# 5. 조인 상태 확인
log_header "5단계: 조인 상태 확인"
log_header "========================================"

log_info "조인 후 상태를 확인합니다..."

# kubelet 서비스 상태 확인
sleep 5
if systemctl is-active --quiet kubelet; then
    log_success "✓ kubelet 서비스가 정상적으로 실행 중입니다."
else
    log_warning "kubelet 서비스 상태를 확인해주세요."
    sudo systemctl status kubelet --no-pager -l
fi

# 설정 파일 생성 확인
if [ -f /etc/kubernetes/kubelet.conf ]; then
    log_success "✓ kubelet 설정 파일이 생성되었습니다."
else
    log_error "kubelet 설정 파일이 생성되지 않았습니다."
fi

# CNI 설정 확인
if ls /etc/cni/net.d/*.conf &>/dev/null; then
    log_success "✓ CNI 설정이 확인되었습니다."
else
    log_info "CNI 설정이 아직 생성되지 않았습니다 (Flannel 설치 후 생성됨)."
fi

echo ""

# 6. Control Plane 확인 안내
log_header "6단계: Control Plane에서 확인"
log_header "========================================"

log_info "Control Plane에서 다음 명령어로 노드 추가를 확인하세요:"
echo ""
echo "   kubectl get nodes"
echo "   kubectl get nodes -o wide"
echo "   kubectl get pods --all-namespaces"
echo ""

# 완료 메시지
log_header "========================================"
log_header "           조인 완료!"
log_header "========================================"
echo ""
log_success "🎉 Worker 노드가 성공적으로 클러스터에 조인되었습니다!"
echo ""

echo "📊 노드 정보:"
echo "   호스트명: $current_hostname"
echo "   IP 주소: $current_ip"
echo "   Control Plane: $CONTROL_PLANE_IP:$API_PORT"

echo ""
echo "📋 다음 단계:"
echo "1. Control Plane에서 'kubectl get nodes'로 노드 확인"
echo "2. Flannel CNI가 설치되어 있다면 자동으로 이 노드에도 배포됨"
echo "3. 노드가 Ready 상태가 될 때까지 대기 (1-2분)"
echo "4. 추가 Worker 노드가 있다면 동일한 과정 반복"

echo ""
echo "❗ 참고사항:"
echo "- Worker 노드에서는 kubectl 명령어를 직접 사용할 수 없습니다"
echo "- 모든 클러스터 관리는 Control Plane에서 수행해야 합니다"
echo "- 이 노드의 상태는 Control Plane에서 확인 가능합니다"

log_header "========================================"