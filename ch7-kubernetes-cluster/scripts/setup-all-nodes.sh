#!/bin/bash

# 쿠버네티스 클러스터 구축을 위한 올인원 설치 스크립트
# 작성자: Kubernetes Lab
# 버전: 1.0
# 
# 이 스크립트는 다음 작업을 순서대로 수행합니다:
# 1. Swap 비활성화
# 2. containerd 설치 및 설정
# 3. 필수 커널 모듈 로드 및 sysctl 설정
# 4. kubeadm, kubelet, kubectl 설치

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

# 스크립트 시작
clear
echo "========================================"
echo "    쿠버네티스 클러스터 구축 준비"
echo "        올인원 설치 스크립트"
echo "========================================"
echo ""
echo "이 스크립트는 쿠버네티스 클러스터 구축을 위한"
echo "모든 사전 준비 작업을 자동으로 수행합니다."
echo ""
echo "수행될 작업:"
echo "1. ✓ Swap 비활성화"
echo "2. ✓ containerd 설치 및 설정"
echo "3. ✓ 커널 모듈 및 sysctl 설정"
echo "4. ✓ kubeadm, kubelet, kubectl 설치"
echo ""

# 계속 진행 여부 확인
while true; do
    read -p "계속 진행하시겠습니까? (y/n): " yn
    case $yn in
        [Yy]* ) 
            break
            ;;
        [Nn]* ) 
            log_info "설치를 취소했습니다."
            exit 0
            ;;
        * ) 
            echo "y 또는 n을 입력해주세요."
            ;;
    esac
done

echo ""
log_header "========================================"
log_header "        설치 시작"
log_header "========================================"

# 현재 스크립트의 디렉토리 경로 구하기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 0. 사전 확인
log_header ""
log_header "0단계: 사전 확인"
log_header "========================================"

log_info "현재 시스템 정보:"
echo "   사용자: $(whoami)"
echo "   호스트: $(hostname)"
echo "   OS: $(lsb_release -d | cut -f2)"
echo "   커널: $(uname -r)"
echo "   아키텍처: $(uname -m)"
echo ""

# sudo 권한 확인
if sudo -n true 2>/dev/null; then
    log_success "sudo 권한이 있습니다."
else
    log_error "sudo 권한이 필요합니다."
    exit 1
fi

# 1. Swap 비활성화
log_header ""
log_header "1단계: Swap 비활성화"
log_header "========================================"

if [ $(swapon --show | wc -l) -eq 0 ]; then
    log_success "Swap이 이미 비활성화되어 있습니다."
else
    log_info "Swap 비활성화 스크립트를 실행합니다..."
    
    # swap 비활성화 스크립트 실행
    if [ -f "$SCRIPT_DIR/disable-swap.sh" ]; then
        bash "$SCRIPT_DIR/disable-swap.sh"
    else
        log_info "disable-swap.sh를 찾을 수 없습니다. 수동으로 비활성화합니다..."
        
        # 수동으로 swap 비활성화
        log_info "임시로 swap 비활성화..."
        sudo swapoff -a
        
        log_info "/etc/fstab에서 swap 항목 주석 처리..."
        sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
        sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
        
        log_success "Swap이 비활성화되었습니다."
    fi
fi

# 2. containerd 설치
log_header ""
log_header "2단계: containerd 설치 및 설정"
log_header "========================================"

if command -v containerd &> /dev/null && systemctl is-active --quiet containerd; then
    log_success "containerd가 이미 설치되고 실행 중입니다."
    echo "   버전: $(containerd --version)"
else
    log_info "containerd 설치 스크립트를 실행합니다..."
    
    if [ -f "$SCRIPT_DIR/install-containerd.sh" ]; then
        # 자동 모드로 containerd 설치 스크립트 실행
        export DEBIAN_FRONTEND=noninteractive
        bash "$SCRIPT_DIR/install-containerd.sh"
    else
        log_error "install-containerd.sh를 찾을 수 없습니다."
        exit 1
    fi
fi

# 3. 커널 모듈 및 sysctl 설정
log_header ""
log_header "3단계: 커널 모듈 및 sysctl 설정"
log_header "========================================"

log_info "필수 커널 모듈 설정 중..."

# 커널 모듈 설정 파일 생성
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# 모듈 로드
sudo modprobe overlay
sudo modprobe br_netfilter

log_success "커널 모듈이 설정되었습니다."

log_info "sysctl 파라미터 설정 중..."

# sysctl 설정 파일 생성
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# 설정 적용
sudo sysctl --system > /dev/null

log_success "sysctl 파라미터가 설정되었습니다."

# 4. 쿠버네티스 구성 요소 설치
log_header ""
log_header "4단계: 쿠버네티스 구성 요소 설치"
log_header "========================================"

if command -v kubeadm &> /dev/null && command -v kubelet &> /dev/null && command -v kubectl &> /dev/null; then
    log_success "쿠버네티스 구성 요소가 이미 설치되어 있습니다."
    echo "   kubeadm: $(kubeadm version -o short)"
    echo "   kubelet: $(kubelet --version)"
    echo "   kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    log_info "쿠버네티스 구성 요소 설치 스크립트를 실행합니다..."
    
    if [ -f "$SCRIPT_DIR/install-kubernetes.sh" ]; then
        # 자동 모드로 쿠버네티스 설치 스크립트 실행
        export DEBIAN_FRONTEND=noninteractive
        bash "$SCRIPT_DIR/install-kubernetes.sh"
    else
        log_error "install-kubernetes.sh를 찾을 수 없습니다."
        exit 1
    fi
fi

# 5. 최종 확인
log_header ""
log_header "5단계: 최종 확인"
log_header "========================================"

log_info "사전 준비 사항 최종 확인 중..."

# 사전 준비 확인 스크립트 실행
if [ -f "$SCRIPT_DIR/check-prerequisites.sh" ]; then
    bash "$SCRIPT_DIR/check-prerequisites.sh"
else
    # 수동으로 주요 항목들 확인
    echo ""
    log_info "주요 설치 항목 확인:"
    
    # Swap 확인
    if [ $(swapon --show | wc -l) -eq 0 ]; then
        log_success "✓ Swap: 비활성화됨"
    else
        log_error "✗ Swap: 활성화됨"
    fi
    
    # containerd 확인
    if command -v containerd &> /dev/null && systemctl is-active --quiet containerd; then
        log_success "✓ containerd: 설치 및 실행 중"
    else
        log_error "✗ containerd: 문제 있음"
    fi
    
    # 쿠버네티스 구성 요소 확인
    if command -v kubeadm &> /dev/null && command -v kubelet &> /dev/null && command -v kubectl &> /dev/null; then
        log_success "✓ Kubernetes: kubeadm, kubelet, kubectl 설치됨"
    else
        log_error "✗ Kubernetes: 구성 요소 누락"
    fi
fi

# 완료 메시지
log_header ""
log_header "========================================"
log_header "           설치 완료!"
log_header "========================================"
echo ""
log_success "🎉 쿠버네티스 클러스터 구축을 위한 사전 준비가 완료되었습니다!"
echo ""

echo "설치된 구성 요소:"
echo "✓ Swap 비활성화"
echo "✓ containerd $(containerd --version | cut -d' ' -f3)"
echo "✓ kubeadm $(kubeadm version -o short)"
echo "✓ kubelet $(kubelet --version | cut -d' ' -f2)"
echo "✓ kubectl $(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | cut -d' ' -f4 || echo "설치됨")"

echo ""
echo "📋 다음 단계:"
echo ""
echo "Control Plane 노드에서:"
echo "  1. kubeadm init --pod-network-cidr=192.168.0.0/16"
echo "  2. mkdir -p \$HOME/.kube"
echo "  3. sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "  4. sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo ""
echo "Worker 노드에서:"
echo "  1. kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
echo ""
echo "네트워크 플러그인 설치 (Control Plane에서):"
echo "  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml"
echo ""

echo "🔧 유용한 명령어:"
echo "  kubectl get nodes                    # 노드 상태 확인"
echo "  kubectl get pods --all-namespaces   # 모든 파드 상태 확인"
echo "  kubeadm token create --print-join-command  # 새로운 조인 명령어 생성"
echo ""

# 재부팅 권장
echo "⚠️  시스템 재부팅을 권장합니다:"
while true; do
    read -p "지금 재부팅하시겠습니까? (y/n): " yn
    case $yn in
        [Yy]* ) 
            log_info "시스템을 재부팅합니다..."
            sudo reboot
            break
            ;;
        [Nn]* ) 
            log_info "재부팅을 건너뜁니다. 나중에 수동으로 재부팅해주세요."
            echo ""
            echo "재부팅 후 다음 명령어로 상태를 확인하세요:"
            echo "  free -h                    # swap 비활성화 확인"
            echo "  sudo systemctl status containerd  # containerd 상태 확인"
            echo "  kubeadm version            # kubeadm 버전 확인"
            break
            ;;
        * ) 
            echo "y 또는 n을 입력해주세요."
            ;;
    esac
done

echo ""
log_header "========================================"
echo "스크립트 실행이 완료되었습니다. 🚀"
log_header "========================================"