# CHALLA iOS

같은 방(Room)에 모인 사람들이 필름 카메라 감성으로 사진을 찍고 인화를 기다리는 iOS 앱.
Tuist 기반 모듈화 프로젝트이며, 개발자 3명이 협업한다. Feature 모듈은 TCA(The Composable Architecture)로 작성한다.

- 배포 타깃: **iOS 17.0** / iPhone 전용 (`Tuist/ProjectDescriptionHelpers/Environment/Environment.swift`가 기준.
  에이전트·스킬 문서에 다른 OS 버전 표기가 있어도 이 값을 우선한다)
- Tuist 버전: `mise.toml`로 고정 (팀 전원 동일 버전)

## 빌드 · 실행 명령

```bash
mise install                      # 최초 1회: mise.toml에 고정된 Tuist 설치
mise exec -- tuist generate       # 워크스페이스 생성 (Xcode 프로젝트는 커밋 안 됨 — 매번 생성)
mise exec -- tuist build          # 전체 빌드
mise exec -- tuist scaffold module --name <모듈명> --group <그룹>   # 새 모듈 생성 후 tuist generate

# 시뮬레이터 빌드 (스킴 예: CHALLADesignSystemApp)
xcodebuild -workspace CHALLA.xcworkspace -scheme <스킴> \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

- `*.xcodeproj` / `*.xcworkspace` / `Derived/`는 Tuist 생성물이라 gitignore 대상. 직접 수정 금지.
- 로컬 서명값은 `Configs/Shared.xcconfig` (gitignore) — 없으면 `Shared.xcconfig.template` 복사해서 생성.

## 아키텍처 (요약)

레이어: `App → Feature → Domain ← Data → Network → Core·Shared` + UI(CHALLADesignSystem) + DIContainer

> 이 구조는 목표 설계다. 현재 구현된 모듈은 `ls Projects/`로 확인할 것 (초기 단계라 일부 레이어는 아직 생성 전이다).

핵심 규칙 6개 — 위반 금지 (상세: `.claude/rules/architecture.md`, 배경: `docs/ARCHITECTURE.md`):

1. `Feature → Domain ← Data` (Data가 Domain 인터페이스 구현)
2. Feature는 Data를 import 하지 않는다 (DIContainer가 주입)
3. Feature끼리 직접 참조하지 않는다 (네비게이션은 App이 조립)
4. Core · Shared는 누구나 import 가능
5. `CHALLADesignSystem`은 Feature를 import 하지 않는다
6. `CHALLANetwork`는 Data만 import 한다

레이어 판별: **시뮬레이터 없이 유닛테스트가 돌면 Shared, OS를 만지면 Core, 서버를 만지면 Network.**

### 앱 배치 (실배포앱 / 검수앱 / 데모앱)

실행 가능한 앱은 세 종류이며 위치 규칙이 있다 — **실배포앱은 `App/`, 데모·검수앱은 대상 모듈 옆에.**

- `CHALLAApp` (`Projects/App/`) — 실배포앱. 모든 Feature를 조립한 최종 프로덕트
- `CHALLADesignSystemApp` (`Projects/UI/`) — 디자인 시스템 검수앱. DS 컴포넌트를 Variant 단위로 검수, TestFlight 별도 배포
- `XxxFeatureDemo` (각 Feature 모듈 안 `Demo/`) — 피처 데모앱. **새 Feature를 만들면 Demo 앱도 함께 만들어** Mock 데이터로 그 화면만 단독 실행·검증한다.
  데모앱은 앱 조립 지점이므로 예외적으로 Data(Mock)를 주입할 수 있다 (규칙 2의 유일한 예외)

## 컨벤션 (요약)

상세: `docs/CONVENTIONS.md`

- 브랜치: `<type>/#<이슈번호>-<kebab-설명>` (예: `feat/#12-login-screen`) — main 직접 push 금지, 1브랜치 = 1이슈
- 커밋: `[<Type>] #<이슈번호> - <작업 내용>` (예: `[Feat] #12 - 로그인 기능 구현`)
- 타입: `Feat`(기능) / `Fix`(버그) / `Docs`(문서) / `Build`(빌드·세팅 파일) / `Refactor`(리팩터링) / `Chore`(잡일)
- PR 본문에 `Resolved: #이슈번호` 필수, UI 작업은 스크린샷 첨부
- 커밋·푸시는 반드시 사용자 확인 후 실행 (자동 실행 금지). 커밋 메시지에 co-author 표기를 넣지 않는다.

## 서브에이전트 사용 가이드

상황별로 아래 에이전트에 위임한다 (파이프라인 상세: `docs/AI_WORKFLOW.md`):

| 상황 | 에이전트 |
| :-- | :-- |
| "OO 어디 있어?" 코드 위치 탐색 | `swift-search` (직접 grep 하지 말고 위임) |
| 새 Feature 시작 — 구현 전 설계 | `tca-architect` (TCA) / `swift-architect` (일반) |
| 디자인 시안·스크린샷 분석 | `swift-ui-design` |
| TCA 리듀서·액션·의존성 구현 | `tca-engineer` |
| 모델·서비스·네트워킹 등 일반 Swift 구현 | `swift-engineer` |
| SwiftUI 뷰 구현 (코어 로직 완료 후) | `swiftui-specialist` |
| 구현 완료 직후 리뷰 | `swift-code-reviewer` |
| 리뷰 통과 후 테스트 작성 | `swift-test-creator` |
| README·MODULE.md·주석 정리 | `swift-documenter` |

표준 개발 순서: **설계(architect) → 구현(engineer) → 뷰(specialist) → 리뷰(reviewer) → 테스트(test-creator) → 문서(documenter)**.
설계 없이 구현으로 직행하지 않는다.

## 테스트 · 모듈 문서 정책

**모든 모듈은 자기 테스트와 자기 문서를 가진다.** 모듈 하나를 만들면 다음 세 가지가 한 세트다:

```
Projects/<그룹>/<모듈명>/
├── Sources/          # 구현
├── Tests/            # 이 모듈의 Swift Testing 테스트 (모듈 단위로 실행 가능)
└── MODULE.md         # 이 모듈의 책임 · 공개 API · 의존성 기록
```

- 테스트는 Swift Testing(`import Testing`, `@Test`, `#expect`)으로 작성한다 — XCTest 신규 작성 금지
- 레이어별 테스트 초점:
  - **Domain** — UseCase·엔티티 규칙을 순수 유닛테스트로 (시뮬레이터 불필요, 가장 빠르고 두텁게)
  - **Feature** — TCA TestStore로 리듀서의 상태 변화·이펙트를 검증
  - **Data** — Repository 구현을 Mock 네트워크/저장소로 검증
  - **Shared** — 순수 함수 유닛테스트
- 공개 API를 추가·변경하면 같은 PR에서 `MODULE.md`를 갱신한다
- 상세 정책: `.claude/rules/module-docs-tests.md`

## 개인 설정

- 개인 전용 지시는 `CLAUDE.local.md`에 (gitignore됨 — 팀에 공유 안 됨)
- 개인 권한 허용은 `.claude/settings.local.json`에 (gitignore됨). 팀 공유 허용 목록인 `.claude/settings.json`에는 개인 토큰·개인 경로를 절대 넣지 않는다
