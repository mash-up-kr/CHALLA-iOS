---
name: zeplin-ui-verification
description: "구현한 화면의 스크린샷·UI hierarchy를 Zeplin 시안 스펙과 항목별로 대조해 PASS/DIFF를 보고합니다."
---
# Zeplin UI Verification

TRIGGER when: **시안을 근거로 뷰를 구현한 직후 — 사용자가 따로 요청하지 않아도 실행한다.** Zeplin 시안 스펙으로 SwiftUI 뷰·디자인 시스템 컴포넌트를 만들거나 고친 뒤, 사용자가 "시안이랑 비교해줘"라고 할 때, PR에 붙일 UI 검증 결과가 필요할 때.
DO NOT TRIGGER when: 아직 뷰 구현 전일 때(그때는 `swift-ui-design`으로 스펙 추출), 시안이 없는 화면일 때, UI에 영향 없는 변경일 때, 단순히 앱이 동작하는지만 볼 때(그때는 `device-interaction`).

---

## 이 스킬의 위치

```
② 스펙 추출 (swift-ui-design, Zeplin MCP)
      ↓
④ 뷰 구현 (swiftui-specialist)
      ↓
④.5 UI 검증 ← 이 스킬 (요청 없이 자동)
      ↓
⑤ 코드 리뷰 (swift-code-reviewer)
```

**시안 기반 UI 작업의 완료 조건이다.** 사용자가 Zeplin 시안을 주고 개발을 요청했다면,
구현만 하고 "완료"라고 보고하지 않는다 — 검증 표까지 내는 것이 한 작업의 끝이다.
사용자가 "검증해줘"라고 말할 때까지 기다리지 않는다.

시안 스펙을 뽑는 것도, 스크린샷을 찍는 것도 이미 다른 곳에 있다.
이 스킬은 **그 둘을 대조하는 기준**만 정의한다.

| 필요한 것 | 어디서 오는가 |
| :-- | :-- |
| 시안 스펙 (수치) | `swift-ui-design` 에이전트가 Zeplin MCP로 추출 |
| 시안 이미지 | Zeplin 화면 응답의 `image_url` (서명 URL — 만료되므로 매번 새로 받는다) |
| 구현 스크린샷 | `xcrun simctl io booted screenshot` |
| 구현 코드 | Read |

## 두 축으로 대조한다

| 대조 | 근거 | 잡아내는 것 | 적용 범위 |
| :-- | :-- | :-- | :-- |
| **값** | 시안 스펙 ↔ 구현 코드 | 색·크기·행간 수치 오류, 토큰 대신 하드코딩 | **항상** |
| **시각** | 시안 이미지 ↔ 스크린샷 | 요소 누락, 순서 바뀜, 정렬 어긋남, 잘림·겹침 | **Feature 데모앱 화면만** |

값 대조만으로는 "수치는 맞는데 레이아웃이 깨진" 경우를, 시각 대조만으로는
"보기엔 같은데 하드코딩한" 경우를 놓친다.

**시각 대조를 데모앱에 한정하는 이유:** 시뮬레이터를 탭으로 조작하는 도구가 없어 화면 이동이
불가능하다. 데모앱은 실행하면 대상 화면이 바로 떠서 도달 문제가 없지만,
검수앱 갤러리(Color·Typography 등)는 탭해야 들어가므로 캡처할 수 없다.
디자인 시스템은 **값 대조만** 하고, 시각 검수는 디자이너가 검수앱으로 직접 한다.

## 절차

### 1. 시안 스펙 확보

`swift-ui-design`의 **Spec Extraction Output** 표가 있어야 한다.
없으면 Zeplin 화면·컴포넌트를 지정해 `swift-ui-design`을 먼저 돌린다.
대상도 스펙도 없으면 **추측으로 진행하지 말고** 사용자에게 요청하고 멈춘다.

스펙을 뽑은 지 시간이 지났다면(다른 작업을 거쳤거나 날짜가 바뀌었다면) **시안을 다시 조회한다.**
그 사이 디자이너가 수정했을 수 있고, 그러면 DIFF가 나와도 구현이 틀린 건지 시안이 바뀐 건지
구분할 수 없다.

### 2. 검증 대상 앱 선택

| 대상 | 실행할 스킴 |
| :-- | :-- |
| 디자인 시스템 컴포넌트·토큰 | `CHALLADesignSystemApp` (검수 갤러리) — 시안은 Zeplin의 `Theme`·`Typography` 화면 |
| Feature 화면 | 해당 모듈의 `XxxFeatureDemo` |
| 조립된 전체 플로우 | `CHALLAApp` |

Feature 화면은 데모앱에서 검증하는 것을 기본으로 한다 — Mock 데이터로 해당 화면만 단독 실행할 수 있어
상태별 Variant를 만들기 쉽다.

### 3. 캡처

**시안 이미지** — Zeplin 화면 응답의 `image_url`을 받아 Read로 확인한다.

```bash
curl -s -o <스크래치경로>/spec.png "<image_url>"
```

**구현 스크린샷** — 앱을 빌드·실행해 캡처한다.

```bash
# 0. 설치된 기기 확인 — 기기 이름은 맥마다 다르다. 문서 값을 그대로 쓰지 말 것
xcrun simctl list devices available | grep -i iphone

DEVICE='<위 목록에서 고른 기기>'          # 예: iPhone 17
mise exec -- tuist generate --no-open     # 실패하면 ./Scripts/bootstrap.sh 먼저

xcodebuild -workspace CHALLA.xcworkspace -scheme <스킴> \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath /tmp/challa-dd build

xcrun simctl boot "$DEVICE" 2>/dev/null; sleep 8
xcrun simctl install booted /tmp/challa-dd/Build/Products/Debug-iphonesimulator/<스킴>.app
xcrun simctl launch booted <bundle-id>
sleep 4
xcrun simctl io booted screenshot <스크래치경로>/impl.png
```

빌드 실패 시 흔한 원인 두 가지:

- `Fatal linting issues found` + `Configuration file not found ... Shared.xcconfig`
  → `./Scripts/bootstrap.sh` 실행 (gitignore 대상이라 클론·worktree마다 필요)
- xcodebuild가 사용 가능한 destination 목록만 길게 출력하고 실패
  → 지정한 기기가 이 맥에 없음. 0단계 목록에서 다시 고를 것

#### 상태·화면별 캡처 — 진입 인자 규약

탭으로 이동할 수 없으므로 **데모앱은 실행 인자로 진입 지점을 받는다.**

```bash
xcrun simctl launch booted <bundle-id> --screen <화면> --state <상태>
```

| 인자 | 의미 | 예 |
| :-- | :-- | :-- |
| `--screen` | 데모앱 안에서 띄울 화면 | `list`, `detail` |
| `--state` | 그 화면의 상태 | `default`, `loading`, `empty`, `error` |

시안에 정의된 상태를 **하나씩 인자로 띄워 각각 캡처**한다. default 하나만 찍고 끝내지 않는다.
데모앱이 해당 인자를 지원하지 않으면 "확인불가(진입 수단 없음)"로 남기고,
구현 담당에게 인자 추가를 요청한다. 스크린샷을 상상해서 판정하지 않는다.

### 4. 항목별 대조

| 카테고리 | 확인 내용 | 판정 근거 |
| :-- | :-- | :-- |
| 계층 구조 | 컨테이너 중첩·순서가 시안과 같은가 | UI hierarchy |
| 간격·패딩 | 화면 여백, 요소 간 spacing | hierarchy의 frame 좌표 |
| 타이포 | 폰트·크기·행간·줄 수 제한 | 스크린샷 + 코드 |
| 색상 | 배경·전경·보더 | 스크린샷 + 코드 |
| 터치 타겟 | 탭 가능한 요소가 44×44pt 이상인가 | hierarchy의 frame |
| 상태 Variant | 시안의 상태가 전부 구현됐는가 | 상태별 스크린샷 |
| 잘림·겹침 | 텍스트 truncation, 요소 겹침 | 스크린샷 |

**코드도 함께 확인한다.** 스크린샷만으로는 `CHALLAColor.primary`를 쓴 것과 같은 색을 하드코딩한 것을
구분할 수 없다. 색·폰트·간격은 구현 코드에서 토큰을 썼는지까지 본다
(`.claude/rules/design-system.md` — 원시값 하드코딩 금지).

#### 시각 대조 규칙

- **이미지 크기가 다르다.** 시안은 디자인 캔버스 해상도, 스크린샷은 기기 픽셀이다.
  **눈으로 절대 수치를 재지 않는다** — 비율·순서·정렬·요소 유무만 판정하고 수치는 값 대조에 맡긴다
- **문서형 시안은 시각 대조 대상이 아니다.** `Theme`·`Typography`처럼 가로로 넓은 설명 페이지는
  iOS 화면과 구조가 애초에 다르다. 값 대조만 한다

### 5. 보고

PR에 그대로 붙일 수 있는 표로 낸다.

```markdown
## UI 검증 — <화면 이름> (Zeplin screen id: 6a65...)

| 항목 | 시안 | 구현 | 판정 |
| :-- | :-- | :-- | :-- |
| 화면 좌우 여백 | 20 | 20 | PASS |
| 버튼 배경 | `CHALLAColor.primary` | `CHALLAColor.primary` | PASS |
| 버튼 높이 | 52 | 48 | **DIFF** |
| 구분선 색 | `#2B2B2B` (토큰 없음) | `Color(hex:)` 하드코딩 | **DIFF** — 토큰 추가 필요 |
| disabled 상태 | 시안 없음 | 구현됨 | 확인불가 — 디자이너 확인 필요 |

**DIFF 2건 / 확인불가 1건**
```

판정은 셋만 쓴다:

- **PASS** — 시안과 일치
- **DIFF** — 다름. 무엇이 어떻게 다른지 수치로 적는다 ("살짝 좁음" 같은 표현 금지)
- **확인불가** — 시안에 정의가 없거나, 해당 상태를 재현할 수 없었음. 누구에게 무엇을 물어야 하는지 적는다

## 하지 말 것

- 픽셀 단위 이미지 diff를 시도하지 않는다 — 렌더링 차이로 오탐이 많다. 항목별 대조로 충분하다
- DIFF를 발견했다고 이 스킬 안에서 코드를 고치지 않는다. 보고까지가 역할이고, 수정은 사용자 확인 후 구현 담당이 한다
- 시안에 없는 값을 "이게 더 자연스럽다"며 PASS 처리하지 않는다 — 확인불가로 남기고 디자이너 확인을 요청한다
