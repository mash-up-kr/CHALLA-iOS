# CHALLADesignSystem

## 책임 (레이어: UI)

찰나의 디자인 토큰(색·타이포그래피·둥글기·아이콘)과 공용 SwiftUI 컴포넌트를 제공한다.

이 모듈은 SwiftUI 기반이며, SwiftUI에 대응 API가 없는 시스템 동작이 필요할 때에 한해
UIKit을 제한적으로 사용한다 (현재 유일: 드로어 닫힘 시 키보드 동시 내림). Feature가
이 모듈을 가져다 쓰는 것이며, 역방향(디자인 시스템 → Feature) 참조는 금지다 (아키텍처 규칙 5).

## 공개 API

### Foundation (토큰)

| API | 설명 |
| :-- | :-- |
| `CHALLAColor` | 색 토큰. Figma Theme 변수와 1:1 (Primary/Label/Background/Status/Fill/Line/Static/Material) |
| `CHALLATypography` + `challaFont(_:)` | 타이포 토큰. Figma 줄 높이까지 재현 (`.heading` / `.body` / `.caption`) |
| `CHALLARadius` | 모서리 둥글기 토큰 (small 8 / medium 10 / large 12) |
| `CHALLAIcon` | 아이콘 토큰 20종 + `Size`(16~32pt) + `image(size:color:)` |
| `CHALLAHitTarget` | HIG 최소 터치 타깃(44pt) 정책 — `minimum` + `inset(for:)` + 도형 확장 헬퍼 `expandedToHitTarget(from:)`. DS 컴포넌트로 담기 애매한 Feature의 일회성 탭 요소에도 사용 |
| `CHALLAFontRegister` | 커스텀 폰트 등록. 앱 진입점(@main) init에서 1회 호출 |

### Components

| API | 설명 |
| :-- | :-- |
| `CHALLATextButton` | 텍스트 버튼. variant(primary/neutral/transparent) × size(large/medium/small), leading/trailing 아이콘 옵션, `role: .destructive` 옵션(위험 액션 — primary는 빨간 채움, neutral·transparent는 빨간 글자), `isFullWidth` 옵션(부모 폭 채움 — 드로어 등) |
| `CHALLAIconButton` | 아이콘 버튼. 정사각(54/40/32), variant·size는 텍스트 버튼과 공용 (role 미지원 — Figma에 destructive 아이콘 버튼 정의 없음) |
| `CHALLAButtonVariant` / `CHALLAButtonSize` | 두 버튼이 공유하는 스타일·크기 enum |
| `CHALLAButtonRole` | 버튼 의미 표시 — variant(생김새)와 조합해 쓴다 (SwiftUI `Button(role:)`과 동일 개념). 현재 `.destructive` 하나. destructive 비활성 디자인은 Figma에 없어 공통 비활성 팔레트로 표시 |
| `CHALLATextField` | 텍스트필드. 상태 5가지(placeholder/focus/typing/typed/disabled)를 입력값·포커스·활성 여부로 자동 판별. customize: `textAlignment`(기본 중앙) · `typography`(기본 body.medium.medium) · `borderColor`(기본 Primary.yellow, 포커스 테두리+커서 색) |
| `CHALLATopNavigation` | 탑 내비게이션 바 (높이 70, 상태바 제외). `.main(trailing:)` = 좌측 홈 로고 고정, `.sub(title:leading:trailing:)` = 중앙 타이틀. 슬롯은 `Item.icon(...)`으로 생성 (아이콘 24pt + 터치 40pt, accessibilityLabel 필수) |
| `CHALLADrawer` | 하단 드로어 레이아웃. 헤더(`.handle` 손잡이 / `.title` 타이틀+닫기) × 콘텐츠 슬롯(@ViewBuilder, 선택) × 버튼(0~2개 + 보조 액션). 버튼 크기·전체 폭·간격·개수는 드로어가 강제 |
| `CHALLADrawerAction` | 드로어 버튼 한 자리의 내용(글자·variant·role·isEnabled·동작). 보조 액션 자리는 variant 무시하고 항상 텍스트형 |
| `CHALLADrawerMessage` | 드로어 콘텐츠 슬롯용 제목+설명 안내 블록 (회원 탈퇴류 반복 패턴 공용화) |
| `challaDrawer(isPresented:allowsInteractiveDismiss:drawer:)` | 드로어 프레젠테이션 View 확장 — 딤·하단 등장/퇴장 스프링·끌어내려 닫기·딤 탭 닫기. `allowsInteractiveDismiss: false`면 닫기 버튼으로만 닫힘(입력 보호). 네이티브 .sheet 미사용(떠 있는 카드 모양이 안 나옴) |

버튼·텍스트필드 비활성화는 별도 파라미터 없이 SwiftUI 표준 `.disabled(_:)`로 제어한다
(내부에서 `@Environment(\.isEnabled)`를 읽어 비활성 색을 적용).

알려진 제약: `CHALLATextField`의 포커스는 내부에서만 관리된다 — 화면 진입 시 키보드 자동
표시 같은 외부 프로그래밍 포커스는 아직 불가 (실사용 화면에서 필요해지면 API 추가 예정).

## 의존 관계

- 이 모듈이 의존하는 모듈: 없음 (SwiftUI 사용, 키보드 내림 등 일부 시스템 동작만 UIKit)
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
