# CHALLA 디자인 시스템

CHALLA의 디자인 시스템(`CHALLADesignSystem`)과 검수용 앱(`CHALLADesignSystemApp` /
표시이름 **"CHALLA 디자인 시스템"**) 구축 방침을 정리한 문서입니다.

---

## 목표

- 실제 서비스 앱에서 사용하는 **공통 디자인 시스템 모듈**을 만든다.
- 동시에 **디자이너가 TestFlight로 컴포넌트를 검수할 수 있는 전용 앱**을 만든다.
- 참고 레퍼런스: YDS(Yello Design System)의 검수용 샘플앱 "YDS Stage".
  - 상용 앱에서는 재현하기 어려운 상태값(disabled 등)까지 **Variant 단위로 꼼꼼히 검수**.

---

## 관리 방식: Tuist 내부 모듈 (선택된 방식)

디자인 시스템을 관리하는 3가지 후보 중 **3번(Tuist 내부 모듈)** 을 선택했다.

| 방식 | 설명 | 채택 |
| :-- | :-- | :-- |
| 1. 별도 레포 + Remote SPM | 버전 관리 분리 | ❌ 초기 복잡도 과함 |
| 2. 같은 레포 + Local SPM | | ❌ |
| 3. **같은 레포 + Tuist 내부 모듈** | 실앱·검수앱이 같이 import | ✅ **채택** |

### 선택 이유

- 아직 디자인 시스템 초기 구축 단계라 **변경이 잦다** → 버전 태그 왕복은 병목.
- 실앱(`CHALLAApp`)과 검수앱(`CHALLADesignSystemApp`)이 **같은 코드를 바라보는 것**이 중요.
- 별도 레포/SPM 버전 관리는 초기에 복잡도가 너무 크다.
- Tuist 모듈화 구조 안에서 공통 UI 모듈로 관리하는 것이 현 프로젝트에 자연스럽다.
- DS 수정과 그것을 쓰는 코드 수정을 **한 PR 안에서** 끝낼 수 있어 리뷰가 쉽다.
- 검수앱이 같은 워크스페이스에 있어, DS를 깨는 변경이 **CI에서 바로 감지**된다 (안전망).

---

## 이름 규칙 (2겹)

| 구분 | 값 | 설명 |
| :-- | :-- | :-- |
| 디자인 시스템 **모듈** (라이브러리) | `CHALLADesignSystem` | 실앱·검수앱이 공유하는 순수 UI 모듈 |
| 검수 **앱** 타깃 (코드/폴더) | `CHALLADesignSystemApp` | 영문 ASCII (빌드/번들ID/경로 안전) |
| 검수 앱 **표시 이름** (홈화면/TestFlight) | `CHALLA 디자인 시스템` | 한글 OK — `CFBundleDisplayName` |

- 코드/타깃명은 영문 ASCII를 쓴다 (한글 타깃명은 빌드·번들ID·경로에서 문제 발생).
- 디자이너가 폰에서 보는 표시 이름만 한글로 둔다.

---

## 목표 구조

```
CHALLA/
├─ mise.toml                        # Tuist 버전 고정 (팀 전원 동일 버전 사용)
├─ Tuist.swift
├─ Workspace.swift
│
├─ Projects/
│  ├─ App/
│  │  └─ CHALLAApp/                 # 실제 서비스 앱 → CHALLADesignSystem 의존
│  │
│  └─ UI/                           # 디자인시스템 모듈 + 검수앱을 한 세트로
│     ├─ CHALLADesignSystem/        # 순수 SwiftUI UI 모듈 (Feature import 금지)
│     │  ├─ Project.swift
│     │  └─ Sources/
│     │     ├─ Foundation/          # 토큰 (원자 계층)
│     │     │  ├─ CHALLAColor.swift        # Color(hex:) 는 여기서만 호출
│     │     │  ├─ CHALLATypography.swift   # Font.custom 은 여기서만 호출
│     │     │  ├─ CHALLASpacing.swift
│     │     │  └─ CHALLARadius.swift
│     │     ├─ Components/          # 재사용 컴포넌트
│     │     │  ├─ CHALLAButton.swift
│     │     │  ├─ CHALLATextField.swift
│     │     │  ├─ CHALLABottomSheet.swift
│     │     │  └─ CHALLAToast.swift
│     │     └─ Resources/           # 폰트 ttf, 아이콘 애셋
│     │
│     └─ CHALLADesignSystemApp/     # 검수 앱 (표시이름: "CHALLA 디자인 시스템")
│        ├─ Project.swift
│        └─ Sources/
│           ├─ CHALLADesignSystemApp.swift   # @main
│           ├─ RootView.swift                # Foundation / Component 섹션 목록
│           ├─ Foundation/                    # 토큰 검수 화면
│           │  ├─ TypographyGallery.swift
│           │  ├─ ColorGallery.swift
│           │  ├─ RadiusShadowGallery.swift
│           │  ├─ IconGallery.swift
│           │  └─ SpacingGallery.swift
│           └─ Component/                     # 컴포넌트 Variant 검수 화면
│              ├─ ButtonGallery.swift         # 모든 style × state 나열
│              ├─ ChipsGallery.swift
│              └─ ...
```

> 검수앱은 디자인시스템에 종속되므로 `UI/` 아래에 **DS 모듈과 한 세트**로 둔다.
> (자세한 앱 배치 규칙은 `ARCHITECTURE.md`의 "앱 · 데모앱 배치 전략" 참고.)

검수앱 카탈로그 구조(YDS Stage 참고):

```
CHALLA 디자인 시스템
├─ Foundation          ← 디자인 토큰 검수
│  ├─ Typography
│  ├─ Color
│  ├─ Radius & Shadow
│  ├─ Icon
│  └─ Spacing
└─ Component           ← 컴포넌트 Variant 검수
   ├─ Button
   │   └─ BoxButton/XLarge
   │       ├─ Primary/Enabled
   │       ├─ Primary/Disabled     ← 상용앱에선 보기 힘든 상태까지
   │       ├─ Highlight/Enabled
   │       └─ ...
   ├─ Chips
   └─ ...
```

---

## 규칙

- `CHALLADesignSystem`은 **Feature 모듈을 import 하지 않는다**. (맨 아래 UI 레이어)
- `CHALLADesignSystem`은 **최대한 순수 SwiftUI 기반 UI 모듈**로 유지한다.
- Feature 모듈에서 `Color(hex:)`, `Font.custom` 등을 **직접 쓰지 않는다**.
  → `CHALLAColor.primary`, `CHALLAFont.title` 같은 **토큰**만 사용한다.
  → `Color(hex:)`, `Font.custom` 원시 호출은 `Foundation/` 안에서만 한다.
- `CHALLADesignSystemApp`은 실제 서비스 기능 없이 **디자인 시스템 컴포넌트만 검수**한다.
- **검수앱 전용 Preview/Mock 코드는 디자인 시스템 컴포넌트 내부에 섞지 않는다.**
  - 개발용 `#Preview`(Xcode 캔버스): DS 모듈 안에 둬도 됨 (필요 시 `#if DEBUG`).
  - 검수 카탈로그 화면(디자이너가 TestFlight로 탐색): `CHALLADesignSystemApp`에 둔다.

### Variant 나열 방식 (선택: 방법 1 — 수동/정석)

컴포넌트의 모든 상태 조합(Variant)을 검수앱에 어떻게 노출할지 두 방법이 있음:

- **방법 1 (채택): Gallery 화면에 수동 나열**
  각 Variant를 `CHALLADesignSystemApp`의 Gallery 파일에서 직접 나열.
  DS 모듈이 100% 순수하게 유지됨. **정석.**
  단, 새 style 추가 시 Gallery 수정을 깜빡하면 검수 누락 위험 → PR 리뷰로 보완.
- 방법 2 (미채택): DS가 `#if DEBUG`로 `previewVariants`를 자가 노출 → 자동 나열.
  검수 누락은 없지만 DS 순수성 규칙과 충돌.

> 초기에는 방법 1로 간다. 검수 누락이 실제 문제로 커지면 방법 2로 전환 검토.

---

## 배포 · CI/CD

배포 전략(앱 2개 분리, 파이프라인, 수동 절차)은 **`docs/DEPLOYMENT.md`** 로 분리했다.
실 구현은 이슈 #8에서 진행 중 (CI는 GitHub Actions, 배포는 Xcode Cloud).

---

## 검수 워크플로우 (YDS Stage 방식)
1. 디자이너가 Figma 컴포넌트/토큰 업데이트
2. 개발자가 검수앱에 해당 Variant(모든 상태) 반영
3. 검수앱 TestFlight 배포 → 디자이너가 실기기에서 Figma와 1:1 대조
4. 피드백 → 수정 → 재배포 (반복)
