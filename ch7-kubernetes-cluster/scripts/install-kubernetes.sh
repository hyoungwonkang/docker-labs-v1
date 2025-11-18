#!/bin/bash

# 쿠버네티스 구성 요소 설치 스크립트 (kubeadm, kubelet, kubectl)
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

# 쿠버네티스 버전 설정 (최신 안정 버전)
K8S_VERSION="1.28"
K8S_VERSION_FULL="1.28.0-00"

echo "========================================"
echo "    쿠버네티스 구성 요소 설치 스크립트"
echo "========================================"
echo ""
echo "설치할 구성 요소:"
echo "- kubeadm: 클러스터 생성 및 관리 도구"
echo "- kubelet: 노드 에이전트"
echo "- kubectl: 클러스터 제어 도구"
echo ""
echo "대상 버전: Kubernetes $K8S_VERSION"
echo ""

# 1. 사전 요구사항 확인
log_info "1. 사전 요구사항 확인 중..."

# Swap 확인
if [ $(swapon --show | wc -l) -ne 0 ]; then
    log_error "Swap이 활성화되어 있습니다. 먼저 비활성화해주세요."
    echo "   명령어: sudo swapoff -a"
    exit 1
else
    log_success "✓ Swap이 비활성화되어 있습니다."
fi

# containerd 확인
if command -v containerd &> /dev/null && systemctl is-active --quiet containerd; then
    log_success "✓ containerd가 실행 중입니다."
else
    log_error "containerd가 설치되어 있지 않거나 실행되고 있지 않습니다."
    echo "   설치 스크립트: ./install-containerd.sh"
    exit 1
fi
echo ""

# 2. 기존 쿠버네티스 설치 확인
log_info "2. 기존 쿠버네티스 설치 확인 중..."
existing_install=false

if command -v kubeadm &> /dev/null; then
    log_warning "kubeadm이 이미 설치되어 있습니다."
    echo "   현재 버전: $(kubeadm version -o short)"
    existing_install=true
fi

if command -v kubelet &> /dev/null; then
    log_warning "kubelet이 이미 설치되어 있습니다."
    echo "   현재 버전: $(kubelet --version)"
    existing_install=true
fi

if command -v kubectl &> /dev/null; then
    log_warning "kubectl이 이미 설치되어 있습니다."
    echo "   현재 버전: $(kubectl version --client --short 2>/dev/null || echo "클라이언트 버전만 확인 가능")"
    existing_install=true
fi

if $existing_install; then
    while true; do
        read -p "기존 설치를 유지하시겠습니까? (y/n): " yn
        case $yn in
            [Yy]* ) 
                log_info "기존 설치를 유지합니다."
                exit 0
                ;;
            [Nn]* ) 
                log_info "새로 설치를 진행합니다."
                break
                ;;
            * ) 
                echo "y 또는 n을 입력해주세요."
                ;;
        esac
    done
fi
echo ""

# 3. 시스템 업데이트
log_info "3. 시스템 패키지 목록 업데이트 중..."
if sudo apt-get update; then
    log_success "패키지 목록이 업데이트되었습니다."
else
    log_error "패키지 목록 업데이트에 실패했습니다."
    exit 1
fi
echo ""

# 4. 필수 패키지 설치
log_info "4. 필수 패키지 설치 중..."
if sudo apt-get install -y apt-transport-https ca-certificates curl gpg; then
    log_success "필수 패키지가 설치되었습니다."
else
    log_error "필수 패키지 설치에 실패했습니다."
    exit 1
fi
echo ""

# 5. 쿠버네티스 GPG 키 추가
log_info "5. 쿠버네티스 공식 GPG 키 추가 중..."

# 기존 키 제거 (있다면)
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 키 디렉토리 생성
sudo mkdir -p /etc/apt/keyrings

# GPG 키 다운로드 및 추가
if curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; then
    log_success "쿠버네티스 GPG 키가 추가되었습니다."
else
    log_error "쿠버네티스 GPG 키 추가에 실패했습니다."
    exit 1
fi
echo ""

# 6. 쿠버네티스 리포지토리 추가
log_info "6. 쿠버네티스 리포지토리 추가 중..."

# 리포지토리 추가
if echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list; then
    log_success "쿠버네티스 리포지토리가 추가되었습니다."
else
    log_error "쿠버네티스 리포지토리 추가에 실패했습니다."
    exit 1
fi

# 패키지 목록 업데이트
if sudo apt-get update; then
    log_success "패키지 목록이 업데이트되었습니다."
else
    log_error "패키지 목록 업데이트에 실패했습니다."
    exit 1
fi
echo ""

# 7. 쿠버네티스 구성 요소 설치
log_info "7. 쿠버네티스 구성 요소 설치 중..."

# 사용 가능한 버전 확인
log_info "사용 가능한 kubeadm 버전 확인..."
apt-cache madison kubeadm | head -5

echo ""
log_info "kubeadm, kubelet, kubectl 설치 중... (버전: $K8S_VERSION_FULL)"

if sudo apt-get install -y kubelet=$K8S_VERSION_FULL kubeadm=$K8S_VERSION_FULL kubectl=$K8S_VERSION_FULL; then
    log_success "쿠버네티스 구성 요소가 설치되었습니다."
else
    log_error "쿠버네티스 구성 요소 설치에 실패했습니다."
    echo ""
    log_info "최신 버전으로 재시도합니다..."
    if sudo apt-get install -y kubelet kubeadm kubectl; then
        log_success "최신 버전으로 설치되었습니다."
    else
        log_error "설치에 실패했습니다."
        exit 1
    fi
fi
echo ""

# 8. 패키지 버전 고정 (자동 업데이트 방지)
log_info "8. 패키지 버전 고정 중..."
if sudo apt-mark hold kubelet kubeadm kubectl; then
    log_success "쿠버네티스 패키지 버전이 고정되었습니다."
else
    log_warning "패키지 버전 고정에 실패했습니다."
fi
echo ""

# 9. kubelet 서비스 활성화
log_info "9. kubelet 서비스 활성화 중..."
if sudo systemctl enable kubelet; then
    log_success "kubelet 서비스가 활성화되었습니다."
else
    log_error "kubelet 서비스 활성화에 실패했습니다."
    exit 1
fi

# 참고: kubelet은 kubeadm init 후에 시작됨
log_info "참고: kubelet 서비스는 kubeadm init 실행 후에 시작됩니다."
echo ""

# 10. 설치 확인
log_info "10. 설치 확인 중..."

echo "설치된 버전:"
echo "- kubeadm: $(kubeadm version -o short)"
echo "- kubelet: $(kubelet --version)"
echo "- kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

echo ""
echo "패키지 상태 확인:"
apt-mark showhold | grep -E "(kubeadm|kubelet|kubectl)" && log_success "패키지가 고정되었습니다." || log_warning "일부 패키지 고정이 실패했을 수 있습니다."

echo ""
echo "========================================"
echo "           설치 완료!"
echo "========================================"
echo ""
log_success "쿠버네티스 구성 요소가 성공적으로 설치되었습니다!"
echo ""
echo "다음 단계:"
echo "1. Control Plane 노드에서: kubeadm init 실행"
echo "2. Worker 노드에서: kubeadm join 실행"
echo "3. 네트워크 플러그인 설치 (예: Calico, Flannel)"
echo ""
echo "유용한 명령어:"
echo "  kubeadm config images pull  # 이미지 미리 다운로드"
echo "  kubeadm init --help         # 초기화 옵션 확인"
echo "  kubectl completion bash     # bash 자동완성 설정"
echo ""

# 자동완성 설정 제안
while true; do
    read -p "kubectl bash 자동완성을 설정하시겠습니까? (y/n): " yn
    case $yn in
        [Yy]* ) 
            log_info "kubectl bash 자동완성을 설정합니다..."
            
            # bashrc에 자동완성 추가
            if ! grep -q "kubectl completion bash" ~/.bashrc; then
                echo "" >> ~/.bashrc
                echo "# kubectl autocompletion" >> ~/.bashrc
                echo "source <(kubectl completion bash)" >> ~/.bashrc
                echo "alias k=kubectl" >> ~/.bashrc
                echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
                log_success "자동완성이 ~/.bashrc에 추가되었습니다."
                echo "새 터미널을 열거나 'source ~/.bashrc'를 실행하세요."
            else
                log_info "자동완성이 이미 설정되어 있습니다."
            fi
            break
            ;;
        [Nn]* ) 
            log_info "자동완성 설정을 건너뜁니다."
            break
            ;;
        * ) 
            echo "y 또는 n을 입력해주세요."
            ;;
    esac
done

echo ""
echo "========================================"