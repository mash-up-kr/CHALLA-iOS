# CHALLADesignSystem

## 책임 (레이어: UI)

찰나의 디자인 토큰(색·타이포그래피·둥글기·아이콘)과 공용 SwiftUI 컴포넌트를 제공한다.

이 모듈은 SwiftUI 외에 아무것도 import하지 않는다. Feature가 이 모듈을 가져다 쓰는
것이며, 역방향(디자인 시스템 → Feature) 참조는 금지다 (아키텍처 규칙 5).

## 공개 API

### Foundation (토큰)

| API | 설명 |
| :-- | :-- |
| `CHALLAColor` | 색 토큰. Figma Theme 변수와 1:1 (Primary/Label/Background/Status/Line/Static/Material) |
| `CHALLATypography` + `challaFont(_:)` | 타이포 토큰. Figma 줄 높이까지 재현 (`.heading` / `.body` / `.caption`) |
| `CHALLARadius` | 모서리 둥글기 토큰 (small 8 / medium 10 / large 12) |
| `CHALLAIcon` | 아이콘 토큰 20종 + `Size`(16~32pt) + `image(size:color:)` |
| `CHALLAHitTarget` | HIG 최소 터치 타깃(44pt) 정책 — `minimum` + `inset(for:)`. 시각 크기 미달 컨트롤의 히트 영역 확장에 공용 사용 |
| `CHALLAFontRegister` | 커스텀 폰트 등록. 앱 진입점(@main) init에서 1회 호출 |

### Components

| API | 설명 |
| :-- | :-- |
| `CHALLATextButton` | 텍스트 버튼. variant(primary/neutral/transparent) × size(large/medium/small), leading/trailing 아이콘 옵션 |
| `CHALLAIconButton` | 아이콘 버튼. 정사각(54/40/32), variant·size는 텍스트 버튼과 공용 |
| `CHALLAButtonVariant` / `CHALLAButtonSize` | 두 버튼이 공유하는 스타일·크기 enum |
| `CHALLATextField` | 텍스트필드. 상태 5가지(placeholder/focus/typing/typed/disabled)를 입력값·포커스·활성 여부로 자동 판별. customize: `textAlignment`(기본 중앙) · `typography`(기본 body.medium.medium) · `borderColor`(기본 Primary.yellow, 포커스 테두리+커서 색) |
| `CHALLATopNavigation` | 탑 내비게이션 바 (높이 70, 상태바 제외). `.main(trailing:)` = 좌측 홈 로고 고정, `.sub(title:leading:trailing:)` = 중앙 타이틀. 슬롯은 `Item.icon(...)`으로 생성 (아이콘 24pt + 터치 40pt, accessibilityLabel 필수) |

버튼·텍스트필드 비활성화는 별도 파라미터 없이 SwiftUI 표준 `.disabled(_:)`로 제어한다
(내부에서 `@Environment(\.isEnabled)`를 읽어 비활성 색을 적용).

## 의존 관계

- 이 모듈이 의존하는 모듈: 없음 (SwiftUI만 사용)
- 이 모듈에 의존하는 모듈: 모든 Feature, `CHALLADesignSystemApp`

## 사용 규칙

- 다른 모듈에서 `Color(hex:)`·`Font.custom` 등 원시 호출 금지 — 반드시 토큰만 사용
  (상세: `.claude/rules/design-system.md`)
- 새 토큰·컴포넌트를 추가하면 `CHALLADesignSystemApp` 갤러리에 Variant 전수를 나열한다
  — 누락 시 디자이너 검수 불가
- 아이콘 추가 절차: Figma 인벤토리 등록 → SVG export → `Resources/Icons.xcassets`에
  imageset 추가(template 렌더링 + 벡터 보존 필수) → `CHALLAIcon`에 케이스 추가
  (갤러리는 `allCases` 기반이라 자동 반영)

## 검증 방법

- **시각 검증(1차)**: `CHALLADesignSystemApp` 스킴 실행 → 갤러리에서 Figma와 대조.
  뷰(버튼·아이콘 렌더링)는 유닛테스트 대신 이 갤러리 검수가 테스트를 대신한다
- **로직 테스트**: 버튼 색 매핑(`CHALLAButtonVariant`) 등 순수 로직의 Swift Testing 검증은
  테스트 타깃 자동화(이슈 #8) 머지 후 추가 예정
