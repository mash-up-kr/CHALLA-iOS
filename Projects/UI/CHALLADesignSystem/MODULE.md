# CHALLADesignSystem

## 책임 (레이어: UI)

찰나의 디자인 토큰(색·타이포그래피·둥글기·아이콘)과 공용 SwiftUI 컴포넌트를 제공한다.

이 모듈은 SwiftUI 기반이며, 예외 의존은 둘뿐이다 — SwiftUI에 대응 API가 없는 시스템 동작에
한한 UIKit(현재 유일: 드로어 닫힘 시 키보드 동시 내림), 그리고 `CHALLAAsyncImage`의 이미지
로딩용 `CHALLAImageKit`(Core). Feature가 이 모듈을 가져다 쓰는 것이며, 역방향(디자인 시스템
→ Feature) 참조는 금지다 (아키텍처 규칙 5). 네트워크·디스크를 만지는 로딩 로직은 전부
Core에 있고, 이 모듈의 뷰는 로더를 주입받아 소비만 한다.

## 공개 API

### Foundation (토큰)

| API | 설명 |
| :-- | :-- |
| `CHALLAColor` | 색 토큰. Figma Theme 변수와 1:1 (Primary/Label/Background/Status/Fill/Line/Static/Material) + `defaultTheme` — 사용자가 고르는 테마 색의 기본값(레몬에이드=`Primary.yellow`). 강조 요소(리스트 값 글자·스위치 켜짐·텍스트필드 포커스 테두리)가 이 색을 따른다 |
| `CHALLATypography` + `challaFont(_:)` | 타이포 토큰. Figma 줄 높이까지 재현 (`.heading` / `.body` / `.caption`). `lineBoxInset`은 `challaFont`가 글자 상자 위아래에 더하는 여백 — 시안 간격을 옮길 때 이 값을 빼서 보정한다 |
| `CHALLARadius` | 모서리 둥글기 토큰 (small 8 / medium 10 / large 12 / xlarge 16 / xxlarge 44.5) |
| `CHALLAIcon` | 아이콘 토큰 24종 + `Size`(14~32pt — 14는 방 카드 person 실측 예외) + `image(size:color:)`. **VoiceOver에는 읽히지 않는 장식용** — 아이콘이 뜻을 가지는 자리는 호출부가 `.accessibilityLabel(_:)`을 붙인다 |
| `CHALLAHitTarget` | HIG 최소 터치 타깃(44pt) 정책 — `minimum` + `inset(for:)` + 도형 확장 헬퍼 `expandedToHitTarget(from:)`. DS 컴포넌트로 담기 애매한 Feature의 일회성 탭 요소에도 사용 |
| `CHALLAFontRegister` | 커스텀 폰트 등록. 앱 진입점(@main) init에서 1회 호출 |

### Components

| API | 설명 |
| :-- | :-- |
| `CHALLATextButton` | 텍스트 버튼. variant(primary/neutral/transparent) × size(large/medium/small), leading/trailing 아이콘 옵션, `role: .destructive` 옵션(위험 액션 — primary는 빨간 채움, neutral·transparent는 빨간 글자), `isFullWidth` 옵션(부모 폭 채움 — 드로어 등), `isLoading` 옵션(라벨 자리에 로딩 점 + 탭 차단, 색은 isEnabled 기준 유지) |
| `CHALLAIconButton` | 아이콘 버튼. 정사각(54/40/32), variant·size는 텍스트 버튼과 공용 (role 미지원 — Figma에 destructive 아이콘 버튼 정의 없음) |
| `CHALLAButtonVariant` / `CHALLAButtonSize` | 두 버튼이 공유하는 스타일·크기 enum |
| `CHALLAButtonRole` | 버튼 의미 표시 — variant(생김새)와 조합해 쓴다 (SwiftUI `Button(role:)`과 동일 개념). 현재 `.destructive` 하나. destructive 비활성 디자인은 Figma에 없어 공통 비활성 팔레트로 표시 |
| `CHALLALoadingDots` | 로딩 인디케이터. 점 3개 순차 페이드(opacity 1.0↔0.3, 주기 0.6초, 점당 0.2초 지연). customize: `color`(기본 Label.neutral) · `diameter`(기본 6) · `spacing`(기본 5). VoiceOver에서 숨김 처리, Reduce Motion 시 정지 |
| `CHALLATextField` | 텍스트필드. 상태 5가지(placeholder/focus/typing/typed/disabled)를 입력값·포커스·활성 여부로 자동 판별. customize: `textAlignment`(기본 중앙) · `typography`(기본 body.medium.medium) · `borderColor`(기본 `CHALLAColor.defaultTheme`, 포커스 테두리+커서 색) · `focus`(기본 nil, `FocusState<Bool>.Binding` 주입 시 키보드를 외부에서 프로그래밍 제어 — nil이면 내부 관리) |
| `CHALLATopNavigation` | 탑 내비게이션 바 (높이 70, 상태바 제외). `.main(trailing:)` = 좌측 홈 로고 고정, `.sub(title:leading:trailing:)` = 중앙 타이틀. 슬롯은 `Item.icon(...)`으로 생성 (아이콘 24pt + 터치 40pt, accessibilityLabel 필수) |
| `CHALLADrawer` | 하단 드로어 레이아웃. 헤더(`.handle` 손잡이 / `.title` 타이틀+닫기) × 콘텐츠 슬롯(@ViewBuilder, 선택) × 버튼(0~2개 + 푸터 액션). 버튼 크기·전체 폭·간격·개수는 드로어가 강제 |
| `CHALLADrawerAction` | 드로어 버튼 한 자리의 내용(글자·variant·role·isEnabled·동작). 푸터 액션 자리는 variant 무시하고 항상 텍스트형 |
| `CHALLADrawerMessage` | 드로어 콘텐츠 슬롯용 제목+설명 안내 블록 (회원 탈퇴류 반복 패턴 공용화) |
| `challaDrawer(isPresented:allowsInteractiveDismiss:drawer:)` | 드로어 프레젠테이션 View 확장 — 딤·하단 등장/퇴장 스프링·끌어내려 닫기·딤 탭 닫기. `allowsInteractiveDismiss: false`면 닫기 버튼으로만 닫힘(입력 보호). 네이티브 .sheet 미사용(떠 있는 카드 모양이 안 나옴) |
| `CHALLAListRow` | 리스트 행 (높이 52, 설명을 넣으면 74). 이니셜라이저 2종 — 탭 행 `init(_:description:icon:iconColor:accessory:themeColor:action:)` / 토글 행 `init(_:description:icon:iconColor:themeColor:isOn:)`. 아이콘 18pt, 이름 `.body.medium.medium`, 설명 `.body.xsmall.medium`. 제목·설명은 한 줄 고정(말줄임) |
| `CHALLAListRowAccessory` | 탭 행의 우측 요소. `.arrow` · `.arrow(value:)` · `.check(isSelected:)` · `.empty` |
| `CHALLAToast` | 잠시 나타났다 사라지는 알림 (`init(_ message:icon:variant:)`). 높이 50(위아래 9 + 콘텐츠 32), 좌우 16, 간격 8, radius 12, 반투명 `Background.level1` 77% + ultraThinMaterial. 내용만큼 넓어지고 320에서 멈춘다(한 줄 고정, 말줄임). `icon` 생략 = 시안의 `leadingIcon = false`(글자만). `variant`(`.normal` 기본 / `.negative`)는 **아이콘 색만** 정하고 배경·글자색은 공통. 등장·문구 교체 시 VoiceOver 낭독. **표시 시간·배치는 담는 쪽 책임**. 시안의 `positive`·`cautionary`와 `normal`의 기본 아이콘은 렌더된 적이 없어 미구현 — 디자이너 문의 중 |
| `CHALLAListSection` | 행들을 묶는 카드. `init(_ title:content:)` — 제목은 옵션, 배경 `Background.level1` + 둥글기 `CHALLARadius.large`, 안쪽 여백 왼쪽 24 · 오른쪽 16 · 위아래 10, 행 사이 간격·구분선 없음. 제목이 있으면 헤더 블록 44 고정(위 16 + 글자 상자 16 + 아래 12), 제목은 한 줄 고정(말줄임) |
| `CHALLAFilmCard` | 필름 낱장 카드 (3:4 고정 비율). Variant 4종(촬영 전 dashed / 인화대기 blur / 인화완료 / 더보기 `+N`) × 순번(`slotNumber`) 옵션. `width` 지정 시 고정(홈 82·인화 카드 90), nil이면 부모 폭 채움(방 상세 그리드) — 세로는 내부 계산. `aspectRatio` 공개(placeholder 크기 계산용) |
| `CHALLACardItem` | 촬영 중 방 카드 (시안 고정 200×266). 대표 사진 + 딤 2겹(검정 스크림·노랑 틴트) + 제목·인원 + 카메라 카운트 뱃지. 사진은 로드된 `Image?` — nil이면 바닥색. 탭은 호출부가 Button으로 감쌈 |
| `CHALLAPrintCard` | 촬영 완료 방 카드. `Status`(printing/printed) 하나가 상태 칩 색과 낱장 blur/선명을 동시 결정. 낱장 스택은 실측 좌표·회전각 4슬롯에 `CHALLAFilmCard(width: 90)` 재사용, 전체 장수가 4를 넘으면 마지막 슬롯이 `+N` |
| `CHALLAAvatar` | 원형 아바타. `photo: Image?`(nil이면 person placeholder) + `size` 지름 (실측: 프로필 바 30 / 상세·채팅 22 / 팝오버 행 20) |
| `CHALLAProfileBar` | 프로필 바. 아바타 입장 순 최대 9명 + `+N` 칩, 탭 시 멤버 팝오버(초대 코드 + 복사 콜백 + 전체 리스트, maxHeight 450 초과 시 스크롤). 열림 상태는 `isPresented` 바인딩(호출부 소유 — 드로어와 동일), 바 배경 흰(닫힘)↔검정(열림), 바깥 탭 닫기. 바를 화면 가로 중앙에 두는 배치 전제 |
| `CHALLAAsyncImage` | 원격 이미지 뷰. 자기 크기·배율을 측정해 `ImageLoader`로 로드(다운샘플+2단 캐시), 성공 시 페이드인 |
| `EnvironmentValues.challaImageLoader` | 로더 주입 통로. 기본값은 `.default` 설정의 공유 로더 — 주입 없이 동작 |

> **우측 여백이 행 종류마다 다르다** — 시안 안여백이 화살표 행 16, 체크·토글 행 20이다.
> 카드는 16으로 통일하고 체크·토글 행이 각각 4를 더한다(`ListRowMetric.accessoryTrailingInset`).
> 화살표 행만 다른 이유는 우측 32 상자 안에 16 아이콘이 놓여 상자가 4만큼 더 파고들기 때문이다.
> 체크 행은 컴포넌트 정의(`List / Check`)가 21이지만 화면 인스턴스(테마·알림)가 20이다 —
> 배포되는 건 화면이라 화면을 따른다.

버튼·텍스트필드 비활성화는 별도 파라미터 없이 SwiftUI 표준 `.disabled(_:)`로 제어한다
(내부에서 `@Environment(\.isEnabled)`를 읽어 비활성 색을 적용).

### CHALLAAsyncImage 사용법

```swift
// 기본형 — 로딩 중·실패 시 DS 배경 박스, 성공 시 페이드인
CHALLAAsyncImage(url: photo.url)
    .scaledToFill()
    .frame(width: 160, height: 160)

// 커스텀형 — content·placeholder 지정 (SwiftUI AsyncImage와 같은 모양)
CHALLAAsyncImage(url: photo.url) { image in
    image.resizable().scaledToFill()
} placeholder: {
    CHALLAColor.Background.level2
}

// 로더는 앱 루트(CHALLAApp)에서 만들어 주입한다 — 아래는 주입 지점의 실제 코드
AppView(store: store)
    .environment(\.challaImageLoader, imageLoader)
    .task { await imageLoader?.removeExpiredDiskCache() }          // 보관 기간 만료 정리
    .onReceive(메모리 경고 알림) { _ in
        Task { await imageLoader?.evictMemoryCache() }             // 메모리만 비움
    }
```

- 크기(`pointSize`)와 배율(`displayScale`)은 뷰가 스스로 측정해 로더에 넘긴다.
- url·크기 변경 시 이전 로드를 취소하고 재로드하며, 뷰가 사라지면 자동 취소된다.
- 실패 시 별도 UI 없이 placeholder를 유지한다 (#25 결정). 재등장 시 자연 재시도.
- **로더는 앱당 하나다.** 루트에서 주입하면 Environment 기본 로더는 생성되지 않는다
  (`set`은 기본값을 읽지 않는다). 인스턴스가 분리되면 메모리 캐시와 중복 요청 관리도 분리된다.
- 캐시 정리 시점은 App이 정한다 — 만료 정리는 앱 실행당 한 번, 메모리 경고 시에는 메모리만 비운다.
  `CHALLAImageKit`은 `UIApplication`을 직접 구독하지 않는다.

알려진 제약:

- `CHALLAListRow`는 비활성(`.disabled(_:)`) 상태를 지원하지 않는다 — 시안에 해당 상태가 없어
  색을 임의로 정하지 않았다. **`.disabled(true)`를 걸면 시각 변화 없이 터치만 차단된다**
  (토글도 눌리지 않는다). 비활성 표현이 필요하면 디자이너 확인 후 API를 추가한다.
- 테마 색은 아직 **앱 전역 상태가 아니라 컴포넌트 파라미터**다 (`CHALLAListRow.themeColor`,
  `CHALLATextField.borderColor`). 둘 다 `CHALLAColor.defaultTheme`을 기본값으로 쓰지만,
  사용자가 고른 테마를 반영하려면 화면마다 값을 내려줘야 한다.
  → 사용자 선택값을 Environment로 전달하는 테마 시스템은 별도 작업으로 남아 있다
  (컴포넌트가 늘수록 배관 비용이 컴포넌트 수만큼 늘어난다).
- `CHALLAListRow`는 눌림(pressed) 상태 시각 피드백이 없다 (`.buttonStyle(.plain)`) —
  시안에 pressed 상태가 없어 만들지 않았다. 디자이너 확인 항목.
- 카드 안쪽 여백이 왼쪽 24 / 오른쪽 16으로 비대칭인 것은 의도다 —
  `List / Arrow` 컴포넌트 폭 318 + 카드 폭 358 규격에서 나온 값이고,
  우측 아이콘이 32 상자 안에 16으로 들어가 눈에 보이는 여백은 좌우 모두 24가 된다.
- **행 우측 화살표는 시안과 구조가 다르다.** 시안에서 화살표 자리는
  `iconButton / Transparent / Small`(32×32) 인스턴스지만, 구현은 `CHALLAIcon.caretRight`를
  32 상자에 넣어 그린다. 행 전체가 이미 버튼이라 그 안에 `CHALLAIconButton`을 넣으면
  버튼이 중첩돼 VoiceOver가 두 번 멈춘다. **보이는 결과는 같다**(Transparent는 배경 없음) —
  시안과 달라 보여도 되돌리지 말 것.
- **SUIT 폰트 파일은 원본이 아니라 손본 것이다 — 원본으로 덮어쓰지 말 것.**
  배포된 SUIT 2.040은 한글 11,172자 중 **8,504자(76%)를 외곽선 없는 빈 글리프로 내보냈다.**
  cmap에는 매핑이 있어 시스템 폰트 대체가 일어나지 않아, `앚`·`앛`·`탚`·`킽` 같은 글자가
  자리만 차지하고 **화면에서 사라진다**(닉네임 입력에서 발견).
  세 굵기 모두 한글 영역의 빈 글리프 매핑을 cmap에서 제거해, 해당 글자는 시스템 폰트(Apple SD Gothic Neo)로
  폴백돼 보이게 했다. 흔한 2,668자는 손대지 않아 SUIT 그대로다. OFL 1.1이고 Reserved Font Name이 없어 개작이 허용된다.
  - **근본 해결은 전체 음절이 그려진 SUIT로 교체하는 것이다.** 교체할 때는 반드시 커버리지를 먼저 확인한다
    (굵기당 350KB대면 축소판을 의심할 것 — 전체 음절 폰트는 보통 2MB 이상)
- `challaFont`의 행간 보정(`lineBoxInset`)은 **`Text` 높이가 폰트 크기와 같다고 가정한다.**
  실제 `Text`는 폰트의 자연 행높이로 잡힌다 (SUIT 14pt는 토큰의 16이 아니라 약 17.7).
  - **섹션 헤더는 이 가정을 더 이상 쓰지 않는다** — 글자 상자를 `lineHeight`로 못 박아
    블록 44를 산술로 확정했다. 회귀는 `CHALLAListSectionLayoutTests`가 실제 레이아웃을 재서 막는다
  - **`CHALLAListRow`의 제목–설명 간격(6)은 아직 이 가정을 쓴다.** 설명 토큰이 같은 14/16이라
    실제로는 약 6.8로 벌어진다. 행 높이가 74로 고정이라 카드 높이에는 누적되지 않고
    라벨이 행 안에서 약 0.4씩 어긋나는 정도라 그대로 뒀다
  - 상수끼리 비교하는 유닛테스트로는 잡을 수 없다. 화면에서 실제 frame을 재야 확인된다
- 리스트 행·섹션 헤더 높이는 시안 수치로 **고정**이라 Dynamic Type을 따라 늘어나지 않는다.
  글자는 잘리지 않고 여백으로 번져 나가지만, 접근성 큰 글자에서는 시안대로 보이지 않는다.
  → 확대 대응은 컴포넌트 하나가 아니라 DS 전체가 함께 정해야 할 별도 작업이다.

## 의존 관계

- 이 모듈이 의존하는 모듈: `CHALLAImageKit` (Core — 규칙 4에 따라 허용).
  그 외에는 SwiftUI만 쓰며, 키보드 내림 등 일부 시스템 동작에 한해 UIKit을 쓴다
- 이 모듈에 의존하는 모듈: 모든 Feature, `CHALLADesignSystemApp`

## 사용 규칙

- 다른 모듈에서 `Color(hex:)`·`Font.custom` 등 원시 호출 금지 — 반드시 토큰만 사용
  (상세: `.claude/rules/design-system.md`)
- 새 토큰·컴포넌트를 추가하면 `CHALLADesignSystemApp` 갤러리에 Variant 전수를 나열한다
  — 누락 시 디자이너 검수 불가
- 아이콘 추가 절차: Figma 인벤토리 등록 → SVG export → `Resources/Icons.xcassets`에
  imageset 추가(template 렌더링 + 벡터 보존 필수) → `CHALLAIcon`에 케이스 추가
  (갤러리는 `allCases` 기반이라 자동 반영)
- `DownloadSimple`은 Zeplin에서 asset export가 되지 않아 Figma 원본 대신 직접 그린 SVG다
  (Phosphor Bold 기준, 다른 아이콘과 같은 획 두께 2.25). 원본 export를 받으면 교체한다

## 검증 방법

- **시각 검증(1차)**: `CHALLADesignSystemApp` 스킴 실행 → 갤러리에서 Figma와 대조.
  뷰(버튼·아이콘 렌더링)는 유닛테스트 대신 이 갤러리 검수가 테스트를 대신한다
- **로직 테스트**: `mise exec -- tuist test CHALLADesignSystem` — 화면 검수로 못 잡는 계산을 고정한다
  - `CHALLATypographyTests` — 타이포 토큰의 크기·행간 불변식, `lineBoxInset` 계산,
    리스트 행 높이가 전제하는 토큰 수치 고정
  - `CHALLAListRowAccessoryTests` — 행 우측 요소가 값을 잃지 않는지
  - `CHALLAListSectionLayoutTests` — 섹션 카드를 실제로 레이아웃해서 헤더 블록 44 ·
    설정 화면 첫 카드 168을 잰다 (폰트 고유 줄 높이에 밀려 카드가 부풀지 않는지)
  - `CHALLAButtonVariantTests` — 버튼 variant×role 색 매핑 전수
  - `CHALLAColorHexTests` — hex 파싱과 잘못된 입력의 검정 fallback
  - `CHALLAHitTargetTests` — 44pt 터치 타깃 인셋 계산
  - `CHALLAPrintCardTests` · `CHALLAProfileBarTests` — 더보기·넘침 수량(`+N`) 경계값
