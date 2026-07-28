#!/bin/bash
# Xcode Cloud가 클론 직후 자동 실행하는 스크립트 (ci_scripts/ci_post_clone.sh — 경로·이름 고정 규약).
# 이 저장소는 xcodeproj/xcworkspace를 커밋하지 않으므로, 빌드 전에 여기서 생성해야 한다.
#
# 필요한 Xcode Cloud 워크플로우 환경변수:
#   CHALLA_TEAM_ID — Apple Developer 팀 ID (Shared.xcconfig 생성에 사용)
set -euo pipefail

cd "$(dirname "$0")/.."   # 레포 루트로 이동

# 1. mise 설치 (Xcode Cloud 러너에는 없음) → mise.toml 고정 버전으로 tuist 설치
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
mise trust --quiet   # 저장소 mise.toml 신뢰 (미신뢰 상태면 고정 버전이 무시됨)
mise install tuist   # 린트는 GitHub Actions 담당 — swiftlint/swiftformat은 여기서 설치하지 않음

# 2. 서명 설정 생성 — 팀 ID는 저장소에 없으므로 환경변수에서 주입
if [ -z "${CHALLA_TEAM_ID:-}" ]; then
    echo "❌ CHALLA_TEAM_ID 환경변수가 없습니다 — Xcode Cloud 워크플로우 > Environment 에서 설정하세요" >&2
    exit 1
fi
printf 'DEVELOPMENT_TEAM = %s\n' "$CHALLA_TEAM_ID" > Configs/Shared.xcconfig

# 3. 빌드 번호 자동 증가 — Xcode Cloud가 주는 CI_BUILD_NUMBER를 Tuist 매니페스트에 전달
#    (makeAppProject가 TUIST_BUILD_NUMBER를 읽어 buildNumber 파라미터 대신 사용 → 수동 +1 커밋 불필요)
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
    export TUIST_BUILD_NUMBER="$CI_BUILD_NUMBER"
fi

# 4. 외부 SPM 의존성 (도입 전이면 스킵) → 워크스페이스 생성
if [ -f Tuist/Package.swift ]; then
    mise exec -- tuist install
fi
mise exec -- tuist generate --no-open
