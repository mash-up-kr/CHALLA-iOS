#!/bin/bash
# Swift 포맷/린트 검사 — 로컬·CI 공용.
#   ./Scripts/lint.sh        검사만 (CI가 이 모드로 실행)
#   ./Scripts/lint.sh --fix  자동 교정
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"

# mise가 있으면 고정 버전으로, 없으면(CI 등 PATH에 이미 잡힌 환경) 그대로 실행
run() {
    if command -v mise >/dev/null 2>&1; then mise exec -- "$@"; else "$@"; fi
}

if [[ "${1:-}" == "--fix" ]]; then
    run swiftformat .
    run swiftlint --fix --quiet
    echo "✅ 자동 교정 완료 — 변경 내용 확인 후 커밋하세요"
else
    run swiftformat --lint --quiet . \
        || { echo "❌ 포맷 위반 — ./Scripts/lint.sh --fix 로 교정하세요" >&2; exit 1; }
    run swiftlint lint --strict --quiet \
        || { echo "❌ 린트 위반 — 위 목록 수정 후 다시 실행하세요" >&2; exit 1; }
    echo "✅ 린트 통과"
fi
