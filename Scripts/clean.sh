#!/bin/bash
# Tuist 생성물·캐시 초기화 — 빌드가 이유 없이 꼬였을 때 사용.
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"

command -v mise >/dev/null 2>&1 && mise exec -- tuist clean 2>/dev/null || true

# 생성물 제거 (전부 tuist generate 가 다시 만듦 — 커밋 대상 아님)
# -prune: 매치된 디렉터리 내부로는 하강하지 않음 (삭제 대상 안을 순회하다 에러 나는 것 방지)
find . -maxdepth 4 -type d \( -name "Derived" -o -name "*.xcodeproj" -o -name "*.xcworkspace" \) \
    -not -path "./.git/*" -prune -exec rm -rf {} +

echo "✅ 초기화 완료 — tuist generate (또는 ./Scripts/bootstrap.sh) 로 재생성하세요"
