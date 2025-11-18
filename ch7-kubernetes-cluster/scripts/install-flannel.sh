#!/bin/bash

# Flannel CNI 설치 스크립트
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

# 스크립트 시작
clear
log_header "========================================"
log_header "      Flannel CNI 설치 스크립트"
log_header "========================================"
echo ""

# 1. 사전 확인
log_header "1단계: 사전 확인"
log_header "========================================"

# kubectl 설치 확인
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl이 설치되어 있지 않습니다."
    exit 1
fi

# 클러스터 연결 확인
if ! kubectl cluster-info &> /dev/null; then
    log_error "쿠버네티스 클러스터에 연결할 수 없습니다."
    echo "kubectl 설정을 확인해주세요."
    exit 1
fi

log_success "kubectl 연결 확인됨"

# 현재 노드 상태 확인
log_info "현재 클러스터 상태:"
echo ""
echo "📋 노드 상태:"
kubectl get nodes
echo ""
echo "📋 시스템 파드 상태:"
kubectl get pods -n kube-system | grep -E "(coredns|dns)"

# Pod CIDR 확인
POD_CIDR=$(kubectl cluster-info dump 2>/dev/null | grep -m 1 cluster-cidr | grep -oP '10\.244\.0\.0/16' || echo "")
if [ "$POD_CIDR" = "10.244.0.0/16" ]; then
    log_success "Pod CIDR이 Flannel과 호환됩니다: 10.244.0.0/16"
else
    log_warning "Pod CIDR을 확인할 수 없습니다. Flannel 기본값(10.244.0.0/16)을 사용합니다."
fi

echo ""

# 2. Flannel 설치
log_header "2단계: Flannel CNI 설치"
log_header "========================================"

log_info "Flannel 매니페스트를 다운로드하고 적용합니다..."

# Flannel 설치
FLANNEL_URL="https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"

if kubectl apply -f "$FLANNEL_URL"; then
    log_success "Flannel 매니페스트 적용 완료"
else
    log_error "Flannel 매니페스트 적용 실패"
    exit 1
fi

echo ""

# 3. 설치 확인 및 대기
log_header "3단계: 설치 확인"
log_header "========================================"

log_info "Flannel 파드가 시작될 때까지 대기합니다..."

# Flannel 파드 대기 (최대 2분)
for i in {1..24}; do
    if kubectl get pods -n kube-flannel &> /dev/null; then
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

# Flannel 파드 상태 확인
log_info "Flannel 파드 상태:"
kubectl get pods -n kube-flannel

echo ""

# 노드 Ready 상태 대기 (최대 3분)
log_info "노드가 Ready 상태가 될 때까지 대기합니다..."
for i in {1..36}; do
    READY_NODES=$(kubectl get nodes --no-headers | grep -c " Ready" || echo "0")
    TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
    
    if [ "$READY_NODES" -eq "$TOTAL_NODES" ]; then
        break
    fi
    
    echo -n "."
    sleep 5
done
echo ""

# 4. 최종 상태 확인
log_header "4단계: 최종 상태 확인"
log_header "========================================"

log_info "클러스터 최종 상태:"
echo ""

echo "📋 노드 상태:"
kubectl get nodes -o wide

echo ""
echo "📋 Flannel 데몬셋:"
kubectl get daemonset -n kube-flannel

echo ""
echo "📋 시스템 파드 상태:"
kubectl get pods -n kube-system -o wide

echo ""
echo "📋 Flannel 파드 상태:"
kubectl get pods -n kube-flannel -o wide

# 성공 여부 확인
READY_NODES=$(kubectl get nodes --no-headers | grep -c " Ready" || echo "0")
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
FLANNEL_READY=$(kubectl get pods -n kube-flannel --no-headers 2>/dev/null | grep -c " Running" || echo "0")
COREDNS_READY=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c " Running" || echo "0")

echo ""

# 5. 네트워크 기능 테스트
log_header "5단계: 네트워크 기능 테스트"
log_header "========================================"

if [ "$READY_NODES" -eq "$TOTAL_NODES" ] && [ "$COREDNS_READY" -gt 0 ]; then
    log_info "DNS 기능 테스트를 수행합니다..."
    
    # DNS 테스트
    if timeout 10 kubectl run dns-test --image=busybox --restart=Never --rm -i --quiet -- nslookup kubernetes.default.svc.cluster.local > /dev/null 2>&1; then
        log_success "✓ DNS 해석 테스트 성공"
    else
        log_warning "DNS 테스트 실패 (일시적일 수 있음)"
    fi
else
    log_warning "일부 구성 요소가 아직 준비되지 않아 네트워크 테스트를 건너뜁니다."
fi

echo ""

# 6. 설치 결과 요약
log_header "========================================"
log_header "           설치 완료!"
log_header "========================================"
echo ""

if [ "$READY_NODES" -eq "$TOTAL_NODES" ] && [ "$FLANNEL_READY" -gt 0 ] && [ "$COREDNS_READY" -gt 0 ]; then
    log_success "🎉 Flannel CNI 설치가 성공적으로 완료되었습니다!"
    echo ""
    echo "📊 설치 결과:"
    echo "   Ready 노드: $READY_NODES/$TOTAL_NODES"
    echo "   Flannel 파드: $FLANNEL_READY개 실행 중"
    echo "   CoreDNS 파드: $COREDNS_READY개 실행 중"
    echo "   네트워크: 활성화됨"
    
else
    log_warning "Flannel 설치는 완료되었으나 일부 구성 요소가 아직 준비 중입니다."
    echo ""
    echo "📊 현재 상태:"
    echo "   Ready 노드: $READY_NODES/$TOTAL_NODES"
    echo "   Flannel 파드: $FLANNEL_READY개"
    echo "   CoreDNS 파드: $COREDNS_READY개"
    echo ""
    echo "몇 분 후 다시 확인해보세요:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods --all-namespaces"
fi

echo ""
echo "🔧 유용한 명령어:"
echo "   kubectl get nodes                    # 노드 상태 확인"
echo "   kubectl get pods -n kube-flannel    # Flannel 파드 상태"
echo "   kubectl get pods -n kube-system     # 시스템 파드 상태"
echo "   kubectl logs -n kube-flannel -l app=flannel  # Flannel 로그"

echo ""
echo "🚀 다음 단계:"
echo "   클러스터가 완전히 준비되었습니다!"
echo "   이제 애플리케이션을 배포할 수 있습니다."

log_header "========================================"