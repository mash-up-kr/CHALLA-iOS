#!/bin/bash
# CHALLA-iOS 온보딩 스크립트 — 클론 직후 1회 실행: ./Scripts/bootstrap.sh
# 재실행해도 안전하다(이미 갖춰진 단계는 건너뜀).
# --check: 아무것도 설치/변경하지 않고 환경 진단만 출력한다.
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

ok()   { printf '✅ %s\n' "$1"; }
warn() { printf '⚠️  %s\n' "$1"; }
fail() { printf '❌ %s\n' "$1" >&2; exit 1; }

# 1. Xcode — CLT 단독 설치가 아닌 정식 Xcode 필요 (온보딩 실패 1순위라 가장 먼저 검사)
if xcode-select -p 2>/dev/null | grep -q "Xcode"; then
    XCODE_VER=$(xcodebuild -version 2>/dev/null | head -1 || true)
    ok "Xcode: ${XCODE_VER:-버전 확인 불가 — 라이선스 동의 필요할 수 있음 (sudo xcodebuild -license)}"
else
    fail "정식 Xcode가 필요합니다. App Store에서 설치 후: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

# 2. mise — 도구 버전 고정 매니저. brew install tuist 금지 (mise.toml 버전 고정이 깨짐)
if command -v mise >/dev/null 2>&1; then
    ok "mise: $(mise --version)"
elif $CHECK_ONLY; then
    warn "mise 미설치 — ./Scripts/bootstrap.sh 실행 시 설치됩니다"
else
    command -v brew >/dev/null 2>&1 || fail "Homebrew가 필요합니다: https://brew.sh"
    brew install mise
    ok "mise 설치 완료"
fi

# 3. 도구 설치 — mise.toml 고정 버전(tuist·swiftlint·swiftformat). 이미 있으면 아무것도 안 함
if $CHECK_ONLY; then
    mise ls --current 2>/dev/null || warn "도구 미설치"
else
    mise trust --quiet   # 이 저장소의 mise.toml 신뢰 (최초 1회, 없으면 install이 전역 설정을 봄)
    mise install
    ok "도구: tuist $(mise exec -- tuist version 2>/dev/null), swiftlint $(mise exec -- swiftlint version 2>/dev/null), swiftformat $(mise exec -- swiftformat --version 2>/dev/null)"
fi

# 4. 서명 설정 — 개인 팀 ID라 git에 없음. template 복사 후 직접 입력 (기존 파일은 덮어쓰지 않음)
if [ ! -f Configs/Shared.xcconfig ]; then
    if $CHECK_ONLY; then
        warn "Configs/Shared.xcconfig 없음"
    else
        cp Configs/Shared.xcconfig.template Configs/Shared.xcconfig
        warn "Configs/Shared.xcconfig 에 자기 팀 ID를 입력하세요 (Xcode > Settings > Accounts)"
    fi
elif grep -q "YOUR_TEAM_ID" Configs/Shared.xcconfig; then
    warn "Configs/Shared.xcconfig 의 팀 ID가 아직 placeholder입니다 — 실기기/배포 빌드 전에 입력 필요"
else
    ok "Shared.xcconfig 존재 (개인 값 유지)"
fi

# 5. git 훅 — 커밋 전 staged 파일 린트 검사 (.githooks/pre-commit)
if ! $CHECK_ONLY; then
    git config core.hooksPath .githooks
fi
ok "git hooks: $(git config core.hooksPath 2>/dev/null || echo '미설정')"

$CHECK_ONLY && { echo; echo "진단 끝 — 문제가 있으면 ./Scripts/bootstrap.sh 를 실행하세요"; exit 0; }

# 6. 외부 SPM 의존성 해석 — 아직 없으면 스킵 (TCA 등 도입 시 자동 동작)
if [ -f Tuist/Package.swift ]; then
    mise exec -- tuist install
    ok "외부 의존성 설치 완료"
fi

# 7. 워크스페이스 생성 (매번 새로 생성하는 게 정상 — pbxproj는 커밋하지 않음)
mise exec -- tuist generate

echo
ok "온보딩 완료 — Xcode에서 스킴 CHALLADesignSystemApp 선택 후 ⌘R"
echo "   문제가 생기면: ./Scripts/clean.sh 후 tuist generate"
