#!/bin/bash

# Control Plane 노드 초기화 스크립트
# 작성자: Kubernetes Lab
# 버전: 1.0

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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

# 기본 설정
POD_NETWORK_CIDR="192.168.0.0/16"  # Calico 기본값
KUBERNETES_VERSION=""
CONTROL_PLANE_ENDPOINT=""
APISERVER_ADVERTISE_ADDRESS=""
NETWORK_PLUGIN="calico"

# 사용법 출력
usage() {
    echo "Control Plane 노드 초기화 스크립트"
    echo ""
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  -c, --pod-cidr CIDR          Pod 네트워크 CIDR (기본값: 192.168.0.0/16 for Calico)"
    echo "  -v, --version VERSION        Kubernetes 버전 (예: v1.28.0)"
    echo "  -e, --endpoint ENDPOINT      Control Plane 엔드포인트 (HA 구성시)"
    echo "  -a, --advertise-address IP   API 서버 광고 주소"
    echo "  -n, --network-plugin PLUGIN 네트워크 플러그인 정보 표시용 (calico|flannel, 기본값: calico)"
    echo "  -h, --help                   이 도움말 출력"
    echo ""
    echo "네트워크 CIDR 가이드:"
    echo "  - Calico: 192.168.0.0/16 (기본값, 권장)"
    echo "  - Flannel: 10.244.0.0/16 (Flannel 기본값)"
    echo "  - 기타: 10.200.0.0/16, 172.16.0.0/16 등"
    echo ""
    echo "예시:"
    echo "  $0                                    # Calico용 192.168.0.0/16 (기본)"
    echo "  $0 -c 10.244.0.0/16 -n flannel      # Flannel용 표준 CIDR"
    echo "  $0 -c 10.200.0.0/16                 # 사용자 정의 CIDR"
    echo "  $0 -v v1.28.0                       # 특정 쿠버네티스 버전"
    echo "  $0 -e k8s-cluster.local:6443        # HA 엔드포인트 설정"
    echo ""
    echo "참고: CNI는 이 스크립트 완료 후 별도로 설치해야 합니다."
}

# 명령행 인수 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--pod-cidr)
            POD_NETWORK_CIDR="$2"
            shift 2
            ;;
        -v|--version)
            KUBERNETES_VERSION="$2"
            shift 2
            ;;
        -e|--endpoint)
            CONTROL_PLANE_ENDPOINT="$2"
            shift 2
            ;;
        -a|--advertise-address)
            APISERVER_ADVERTISE_ADDRESS="$2"
            shift 2
            ;;
        -n|--network-plugin)
            NETWORK_PLUGIN="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $1"
            usage
            exit 1
            ;;
    esac
done

# 스크립트 시작
clear
log_header "========================================"
log_header "    쿠버네티스 Control Plane 초기화"
log_header "========================================"
echo ""

# 네트워크 플러그인과 CIDR 호환성 검증
if [ "$NETWORK_PLUGIN" = "flannel" ] && [ "$POD_NETWORK_CIDR" != "10.244.0.0/16" ]; then
    log_warning "Flannel은 기본적으로 10.244.0.0/16 CIDR을 사용합니다."
    log_warning "다른 CIDR을 사용하려면 Flannel 설정을 수동으로 수정해야 합니다."
fi

if [ "$NETWORK_PLUGIN" = "calico" ] && [ "$POD_NETWORK_CIDR" = "10.244.0.0/16" ]; then
    log_info "Calico는 10.244.0.0/16 CIDR도 지원하지만, 192.168.0.0/16이 더 일반적입니다."
fi

# 설정 출력
log_info "초기화 설정:"
echo "   Pod Network CIDR: $POD_NETWORK_CIDR"
echo "   Kubernetes Version: ${KUBERNETES_VERSION:-"최신 안정 버전"}"
echo "   Control Plane Endpoint: ${CONTROL_PLANE_ENDPOINT:-"미설정"}"
echo "   API Server Advertise Address: ${APISERVER_ADVERTISE_ADDRESS:-"자동 감지"}"
echo "   Network Plugin: $NETWORK_PLUGIN"

# CIDR 정보 출력
case $POD_NETWORK_CIDR in
    "192.168.0.0/16")
        echo "   └─ IP 범위: 192.168.0.1 ~ 192.168.255.254 (65,534개 IP)"
        ;;
    "10.244.0.0/16")
        echo "   └─ IP 범위: 10.244.0.1 ~ 10.244.255.254 (65,534개 IP)"
        ;;
    "10.200.0.0/16")
        echo "   └─ IP 범위: 10.200.0.1 ~ 10.200.255.254 (65,534개 IP)"
        ;;
    *)
        echo "   └─ 사용자 정의 CIDR"
        ;;
esac
echo ""

# 1. 사전 요구사항 확인
log_header "1단계: 사전 요구사항 확인"
log_header "========================================"

# Control Plane 노드 여부 확인
log_info "Control Plane 노드 확인 중..."
current_hostname=$(hostname)
log_info "현재 호스트명: $current_hostname"

# 사전 준비 사항 확인
log_info "사전 준비 사항 확인 중..."

# Swap 확인
if [ $(swapon --show | wc -l) -ne 0 ]; then
    log_error "Swap이 활성화되어 있습니다. 먼저 비활성화해주세요."
    exit 1
else
    log_success "✓ Swap이 비활성화되어 있습니다."
fi

# containerd 확인
if command -v containerd &> /dev/null && systemctl is-active --quiet containerd; then
    log_success "✓ containerd가 실행 중입니다."
else
    log_error "containerd가 설치되어 있지 않거나 실행되고 있지 않습니다."
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

# 기존 클러스터 확인
if [ -f /etc/kubernetes/admin.conf ]; then
    log_warning "기존 쿠버네티스 클러스터 설정이 발견되었습니다."
    while true; do
        read -p "기존 설정을 초기화하고 새로 시작하시겠습니까? (y/n): " yn
        case $yn in
            [Yy]* ) 
                log_info "기존 클러스터를 초기화합니다..."
                sudo kubeadm reset -f
                sudo rm -rf $HOME/.kube
                break
                ;;
            [Nn]* ) 
                log_error "기존 클러스터가 있으므로 초기화를 중단합니다."
                exit 1
                ;;
            * ) 
                echo "y 또는 n을 입력해주세요."
                ;;
        esac
    done
fi

echo ""

# 2. 이미지 미리 다운로드
log_header "2단계: 필요한 이미지 다운로드"
log_header "========================================"

log_info "클러스터 구성에 필요한 이미지들을 미리 다운로드합니다..."
if sudo kubeadm config images pull ${KUBERNETES_VERSION:+--kubernetes-version=$KUBERNETES_VERSION}; then
    log_success "이미지 다운로드가 완료되었습니다."
else
    log_warning "이미지 다운로드에 실패했지만 계속 진행합니다."
fi

echo ""

# 3. kubeadm init 명령어 구성
log_header "3단계: 클러스터 초기화"
log_header "========================================"

# kubeadm init 명령어 구성
KUBEADM_INIT_CMD="sudo kubeadm init --pod-network-cidr=$POD_NETWORK_CIDR"

if [ -n "$KUBERNETES_VERSION" ]; then
    KUBEADM_INIT_CMD="$KUBEADM_INIT_CMD --kubernetes-version=$KUBERNETES_VERSION"
fi

if [ -n "$CONTROL_PLANE_ENDPOINT" ]; then
    KUBEADM_INIT_CMD="$KUBEADM_INIT_CMD --control-plane-endpoint=$CONTROL_PLANE_ENDPOINT"
fi

if [ -n "$APISERVER_ADVERTISE_ADDRESS" ]; then
    KUBEADM_INIT_CMD="$KUBEADM_INIT_CMD --apiserver-advertise-address=$APISERVER_ADVERTISE_ADDRESS"
fi

log_info "실행할 명령어:"
echo "   $KUBEADM_INIT_CMD"
echo ""

# 최종 확인
while true; do
    read -p "클러스터 초기화를 시작하시겠습니까? (y/n): " yn
    case $yn in
        [Yy]* ) 
            break
            ;;
        [Nn]* ) 
            log_info "클러스터 초기화를 취소했습니다."
            exit 0
            ;;
        * ) 
            echo "y 또는 n을 입력해주세요."
            ;;
    esac
done

# kubeadm init 실행
log_info "클러스터 초기화를 시작합니다..."
echo ""

if eval $KUBEADM_INIT_CMD; then
    log_success "클러스터 초기화가 완료되었습니다!"
else
    log_error "클러스터 초기화에 실패했습니다."
    echo ""
    log_info "문제 해결을 위해 다음 명령어를 실행해보세요:"
    echo "   sudo journalctl -xeu kubelet"
    echo "   sudo kubeadm reset"
    exit 1
fi

echo ""

# 4. kubectl 설정
log_header "4단계: kubectl 설정"
log_header "========================================"

log_info "kubectl 설정을 구성합니다..."

# kubectl 설정 디렉토리 생성
mkdir -p $HOME/.kube

# 관리자 설정 파일 복사
if sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config; then
    log_success "kubectl 설정 파일이 복사되었습니다."
else
    log_error "kubectl 설정 파일 복사에 실패했습니다."
    exit 1
fi

# 파일 소유권 변경
if sudo chown $(id -u):$(id -g) $HOME/.kube/config; then
    log_success "kubectl 설정 파일 권한이 설정되었습니다."
else
    log_error "kubectl 설정 파일 권한 설정에 실패했습니다."
    exit 1
fi

# kubectl 동작 확인
log_info "kubectl 연결을 확인합니다..."
if kubectl cluster-info > /dev/null 2>&1; then
    log_success "kubectl이 클러스터에 연결되었습니다."
else
    log_error "kubectl 클러스터 연결에 실패했습니다."
    exit 1
fi

echo ""

# 5. 클러스터 상태 확인
log_header "5단계: 클러스터 상태 확인"
log_header "========================================"

# kubectl 연결 확인
log_info "kubectl 클러스터 연결을 확인합니다..."
sleep 3

# 최종 상태 출력
log_info "현재 클러스터 상태:"
echo ""

echo "📋 노드 상태 (CNI 설치 전이므로 NotReady 정상):"
kubectl get nodes -o wide

echo ""
echo "📋 시스템 파드 상태 (coredns Pending 상태 정상):"
kubectl get pods -n kube-system

echo ""
echo "📋 클러스터 정보:"
kubectl cluster-info

echo ""
log_warning "현재 노드가 NotReady 상태이고 coredns가 Pending 상태인 것은 정상입니다."
log_warning "CNI(네트워크 플러그인) 설치 후에 Ready 상태가 됩니다."

echo ""

# 6. Worker 노드 조인 명령어 생성
log_header "6단계: Worker 노드 조인 준비"
log_header "========================================"

log_info "Worker 노드 조인 명령어를 생성합니다..."
JOIN_COMMAND=$(kubeadm token create --print-join-command)

if [ $? -eq 0 ]; then
    log_success "Worker 노드 조인 명령어가 생성되었습니다:"
    echo ""
    echo "🔗 다음 명령어를 각 Worker 노드에서 실행하세요:"
    echo ""
    echo "   $JOIN_COMMAND"
    echo ""
    
    # 조인 명령어를 파일로 저장
    echo "$JOIN_COMMAND" > /tmp/kubeadm-join-command.sh
    chmod +x /tmp/kubeadm-join-command.sh
    log_info "조인 명령어가 /tmp/kubeadm-join-command.sh에 저장되었습니다."
else
    log_error "조인 명령어 생성에 실패했습니다."
fi

echo ""

# 완료 메시지
log_header "========================================"
log_header "           초기화 완료!"
log_header "========================================"
echo ""
log_success "🎉 Control Plane 노드 초기화가 성공적으로 완료되었습니다!"
echo ""

echo "📊 클러스터 정보:"
echo "   Control Plane: $(hostname)"
echo "   Pod Network CIDR: $POD_NETWORK_CIDR"
echo "   Kubernetes Version: $(kubectl version --short --client | grep Client | cut -d' ' -f3)"

echo ""
echo "📋 다음 단계:"
echo "1. Worker 노드에서 조인 명령어 실행"
echo "2. CNI(네트워크 플러그인) 설치 - Calico 또는 Flannel"
echo "3. 모든 노드가 Ready 상태인지 확인"
echo "4. 테스트 애플리케이션 배포"

echo ""
echo "🔧 유용한 명령어:"
echo "   kubectl get nodes                    # 노드 상태 확인"
echo "   kubectl get pods --all-namespaces   # 모든 파드 상태 확인"
echo "   kubeadm token create --print-join-command  # 새로운 조인 명령어 생성"
echo ""
echo "🌐 CNI 설치 명령어 ($POD_NETWORK_CIDR CIDR용):"
case $POD_NETWORK_CIDR in
    "192.168.0.0/16")
        echo "   # Calico 설치 (권장)"
        echo "   kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml"
        ;;
    "10.244.0.0/16")
        echo "   # Flannel 설치 (권장)"
        echo "   kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
        ;;
    *)
        echo "   # Calico 설치 (사용자 정의 CIDR)"
        echo "   curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml"
        echo "   sed -i 's/192.168.0.0\\/16/$POD_NETWORK_CIDR/g' calico.yaml"
        echo "   kubectl apply -f calico.yaml"
        ;;
esac

echo ""
echo "📄 조인 명령어 파일 위치: /tmp/kubeadm-join-command.sh"

log_header "========================================"