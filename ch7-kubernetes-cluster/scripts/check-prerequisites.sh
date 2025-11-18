#!/bin/bash

# 쿠버네티스 클러스터 구축을 위한 사전 준비 사항 확인 스크립트
# 작성자: Kubernetes Lab
# 버전: 1.0

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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

# 헤더 출력
echo "========================================"
echo "  쿠버네티스 클러스터 사전 준비 확인"
echo "========================================"
echo ""

# 1. OS 버전 확인
log_info "1. 운영체제 버전 확인 중..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "   OS: $NAME $VERSION"
    if [[ "$ID" == "ubuntu" ]]; then
        if [[ "$VERSION_ID" == "20.04" || "$VERSION_ID" == "22.04" ]]; then
            log_success "지원되는 Ubuntu 버전입니다."
        else
            log_warning "Ubuntu 20.04 또는 22.04 버전을 권장합니다."
        fi
    else
        log_warning "Ubuntu가 아닌 배포판입니다. 호환성을 확인해주세요."
    fi
else
    log_error "OS 버전을 확인할 수 없습니다."
fi
echo ""

# 2. Swap 상태 확인
log_info "2. Swap 상태 확인 중..."
if [ $(swapon --show | wc -l) -eq 0 ]; then
    log_success "Swap이 비활성화되어 있습니다."
else
    log_error "Swap이 활성화되어 있습니다. 비활성화가 필요합니다."
    echo "   현재 Swap 상태:"
    swapon --show
    echo ""
    echo "   Swap 비활성화 명령어:"
    echo "   sudo swapoff -a"
    echo "   sudo sed -i '/ swap / s/^\\(.*\\)$/#\\1/g' /etc/fstab"
fi
echo ""

# 3. containerd 설치 및 실행 상태 확인
log_info "3. containerd 상태 확인 중..."
if command -v containerd &> /dev/null; then
    log_success "containerd가 설치되어 있습니다."
    echo "   버전: $(containerd --version)"
    
    # containerd 서비스 상태 확인
    if systemctl is-active --quiet containerd; then
        log_success "containerd 서비스가 실행 중입니다."
    else
        log_error "containerd 서비스가 실행되고 있지 않습니다."
        echo "   서비스 시작 명령어: sudo systemctl start containerd"
    fi
    
    # containerd 자동 시작 설정 확인
    if systemctl is-enabled --quiet containerd; then
        log_success "containerd 서비스 자동 시작이 설정되어 있습니다."
    else
        log_warning "containerd 서비스 자동 시작이 설정되어 있지 않습니다."
        echo "   자동 시작 설정 명령어: sudo systemctl enable containerd"
    fi
else
    log_error "containerd가 설치되어 있지 않습니다."
    echo "   설치 스크립트 실행: ./install-containerd.sh"
fi
echo ""

# 4. 필수 커널 모듈 확인
log_info "4. 필수 커널 모듈 확인 중..."
required_modules=("overlay" "br_netfilter")
for module in "${required_modules[@]}"; do
    if lsmod | grep -q "^$module"; then
        log_success "$module 모듈이 로드되어 있습니다."
    else
        log_warning "$module 모듈이 로드되어 있지 않습니다."
        echo "   모듈 로드 명령어: sudo modprobe $module"
    fi
done
echo ""

# 5. sysctl 파라미터 확인
log_info "5. sysctl 파라미터 확인 중..."
required_sysctls=(
    "net.bridge.bridge-nf-call-iptables=1"
    "net.bridge.bridge-nf-call-ip6tables=1"
    "net.ipv4.ip_forward=1"
)

for sysctl_param in "${required_sysctls[@]}"; do
    param_name=$(echo $sysctl_param | cut -d'=' -f1)
    expected_value=$(echo $sysctl_param | cut -d'=' -f2)
    current_value=$(sysctl -n $param_name 2>/dev/null || echo "0")
    
    if [ "$current_value" = "$expected_value" ]; then
        log_success "$param_name = $current_value (올바름)"
    else
        log_error "$param_name = $current_value (예상값: $expected_value)"
    fi
done
echo ""

# 6. 메모리 확인
log_info "6. 시스템 리소스 확인 중..."
total_mem=$(free -m | awk '/^Mem:/{print $2}')
cpu_cores=$(nproc)

echo "   CPU 코어: $cpu_cores"
echo "   총 메모리: ${total_mem}MB"

if [ "$cpu_cores" -ge 2 ] && [ "$total_mem" -ge 1800 ]; then
    log_success "Control Plane 노드로 사용 가능한 리소스입니다."
elif [ "$cpu_cores" -ge 1 ] && [ "$total_mem" -ge 900 ]; then
    log_success "Worker 노드로 사용 가능한 리소스입니다."
else
    log_warning "리소스가 부족할 수 있습니다. 최소 요구사항을 확인해주세요."
fi
echo ""

# 7. 네트워크 연결 확인
log_info "7. 네트워크 연결 확인 중..."
if ping -c 1 8.8.8.8 &> /dev/null; then
    log_success "인터넷 연결이 정상입니다."
else
    log_error "인터넷 연결을 확인할 수 없습니다."
fi
echo ""

# 요약
echo "========================================"
echo "           확인 결과 요약"
echo "========================================"

# 핵심 요구사항 재확인
all_good=true

# Swap 확인
if [ $(swapon --show | wc -l) -ne 0 ]; then
    log_error "✗ Swap이 활성화되어 있습니다."
    all_good=false
else
    log_success "✓ Swap이 비활성화되어 있습니다."
fi

# containerd 확인
if command -v containerd &> /dev/null && systemctl is-active --quiet containerd; then
    log_success "✓ containerd가 설치되고 실행 중입니다."
else
    log_error "✗ containerd 설치 또는 설정에 문제가 있습니다."
    all_good=false
fi

echo ""

if $all_good; then
    log_success "모든 사전 준비가 완료되었습니다! 쿠버네티스 설치를 진행할 수 있습니다."
    echo ""
    echo "다음 단계:"
    echo "1. kubeadm, kubelet, kubectl 설치"
    echo "2. Control Plane 초기화"
    echo "3. Worker 노드 조인"
else
    log_error "일부 사전 준비 작업이 완료되지 않았습니다."
    echo ""
    echo "필요한 작업:"
    echo "1. Swap 비활성화 (필수)"
    echo "2. containerd 설치 및 설정 (필수)"
    echo "3. 커널 모듈 및 sysctl 설정"
fi

echo "========================================"