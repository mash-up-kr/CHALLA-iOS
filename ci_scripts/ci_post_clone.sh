#!/bin/bash
# Xcode Cloud가 클론 직후 자동 실행하는 스크립트 (ci_scripts/ci_post_clone.sh — 경로·이름 고정 규약).
# 이 저장소는 xcodeproj/xcworkspace를 커밋하지 않으므로, 빌드 전에 여기서 생성해야 한다.
#
# 필요한 Xcode Cloud 워크플로우 환경변수의 전체 목록과 출처는 docs/DEPLOYMENT.md 표 참고.
set -euo pipefail

cd "$(dirname "$0")/.."   # 레포 루트로 이동

# 1. 필수 환경변수 검사 — 도구 설치(느림)보다 먼저 해서 설정 실수는 즉시 알려준다.
#
#    Configs/Shared.xcconfig 는 gitignore라 러너에 없고, 아래에서 환경변수로 통째로 만든다.
#    이때 template의 키를 "전부" 채워야 한다. 일부만 채우면 두 가지로 터진다:
#      · API_SCHEME 누락 → tuist generate 단계에서 즉사.
#        ATS 예외 도메인은 plist dictionary의 key라 $(API_HOST) 빌드타임 치환이 안 통해서,
#        APIEnvironment(Tuist/ProjectDescriptionHelpers)가 매니페스트에서 이 파일을 직접 읽는다.
#      · KAKAO_NATIVE_APP_KEY 누락 → 빌드는 통과하고 "실행 즉시 죽는 빌드"가 TestFlight에 올라간다
#        (CHALLAAPIEnvironment의 fatalError. CHALLAApp.swift에도 assert가 있지만 Release에서는 컴파일에서 빠진다).
#      · API_SCHEME/API_PORT를 안 넣으면 조용히 https로 나가서, 백엔드가 http면 빌드는 멀쩡한데
#        모든 API 호출이 실패한다. 기본값에 맡기지 않고 둘 다 명시하게 강제한다.
#    Swift fatalError로 죽는 것보다 여기서 변수 이름을 찍고 죽는 편이 원인 파악이 훨씬 빠르다.
#
#    (배열 대신 문자열로 모으는 이유: macOS 기본 bash 3.2는 set -u 와 빈 배열 확장이 충돌한다)
missing=""
[ -n "${CHALLA_TEAM_ID:-}" ]               || missing="$missing CHALLA_TEAM_ID"
[ -n "${CHALLA_API_HOST:-}" ]              || missing="$missing CHALLA_API_HOST"
[ -n "${CHALLA_KAKAO_NATIVE_APP_KEY:-}" ]  || missing="$missing CHALLA_KAKAO_NATIVE_APP_KEY"
[ -n "${CHALLA_API_SCHEME:-}" ]            || missing="$missing CHALLA_API_SCHEME"
# API_PORT는 https에서 비어 있는 게 정상이라 값은 안 보고 "정의됐는지"만 본다.
# 빈 값으로라도 등록하게 해서, 포트를 뺀 것이 실수가 아니라 선택이었음을 남긴다.
[ -n "${CHALLA_API_PORT+defined}" ]        || missing="$missing CHALLA_API_PORT(비워두더라도 등록할 것)"
if [ -n "$missing" ]; then
    echo "❌ 환경변수가 없습니다:$missing" >&2
    echo "   App Store Connect > Xcode Cloud > 워크플로우 > Environment 에서 설정하세요." >&2
    echo "   (API_HOST·KAKAO 키는 secret 으로 체크 — 전체 목록은 docs/DEPLOYMENT.md)" >&2
    exit 1
fi

# 2. 서명 설정 생성.
#    API_PORT는 빈 값이 정상이라(https는 포트를 안 쓴다) 필수 검사에서 뺐다.
#    scheme이 http면 매니페스트가 해당 도메인에 ATS 평문 예외를 자동으로 붙인다.
cat > Configs/Shared.xcconfig <<EOF
// ci_scripts/ci_post_clone.sh 가 Xcode Cloud 환경변수로 생성한 파일 — 직접 수정하지 말 것.
API_SCHEME = ${CHALLA_API_SCHEME}
API_HOST = ${CHALLA_API_HOST}
API_PORT = ${CHALLA_API_PORT}
DEVELOPMENT_TEAM = ${CHALLA_TEAM_ID}
KAKAO_NATIVE_APP_KEY = ${CHALLA_KAKAO_NATIVE_APP_KEY}
EOF

# 3. 서명을 자동으로 전환 — Xcode Cloud는 클라우드 관리 인증서·프로파일로 서명하며 자동 서명을 전제한다.
#    CHALLAApp은 로컬에서 .manual(팀 프로파일 이름 지정)을 쓰는데 그 프로파일은 러너에 없어서,
#    그대로 두면 Archive가 "No profile matching CHALLA_iOS_AppStore_2026" 으로 실패한다.
#    AppSigning.swift 가 이 변수를 보고 manual → automatic 으로 강등한다(로컬·GitHub Actions는 영향 없음).
export TUIST_CLOUD_SIGNING=true

# 4. 빌드 번호 자동 증가 — Xcode Cloud가 주는 CI_BUILD_NUMBER를 Tuist 매니페스트에 전달
#    (makeAppProject가 TUIST_BUILD_NUMBER를 읽어 buildNumber 파라미터 대신 사용 → 수동 +1 커밋 불필요)
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
    export TUIST_BUILD_NUMBER="$CI_BUILD_NUMBER"
fi

# 5. 마케팅 버전은 릴리즈 태그에서 가져온다 (v1.2.0 → 1.2.0).
#    태그 없는 빌드(release/* 브랜치 등)에서는 export하지 않아 매니페스트 기본값이 그대로 쓰인다.
if [[ "${CI_TAG:-}" =~ ^v[0-9] ]]; then
    export TUIST_MARKETING_VERSION="${CI_TAG#v}"
fi

# 6. mise 설치 (Xcode Cloud 러너에는 없음) → mise.toml 고정 버전으로 tuist 설치
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
mise trust --quiet   # 저장소 mise.toml 신뢰 (미신뢰 상태면 고정 버전이 무시됨)
mise install tuist   # 린트는 GitHub Actions 담당 — swiftlint/swiftformat은 여기서 설치하지 않음

# 7. 외부 SPM 의존성 (도입 전이면 스킵) → 워크스페이스 생성
if [ -f Tuist/Package.swift ]; then
    mise exec -- tuist install
fi
mise exec -- tuist generate --no-open
