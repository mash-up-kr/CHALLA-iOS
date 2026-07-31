# SettingFeature

## 레이어와 책임

**Feature 레이어**. 설정 화면(이슈 #35)의 TCA Feature와 SwiftUI 뷰를 담는다.

화면 진입 시 프로필과 현재 테마를 한 번 불러와 보여주고, 각 행을 누르면 어디로 가야 하는지를
`delegate`로 알린다. **화면 전환 자체는 하지 않는다** — 조립은 App의 몫이다 (아키텍처 규칙 3).

**이 화면은 설정 값을 바꾸지 않는다.** 테마 선택·알림·계정 관리는 전부 하위 화면이고 별도 이슈다.
그래서 저장 액션이 없고, `SettingsRepository`의 `update...`는 이 피처에서 호출하지 않는다.

`SettingData`를 import 하지 않는다 (규칙 2) — `@Dependency(\.loadSettingsUseCase)`로만 접근한다.

## 공개 API

- `struct SettingFeature: Reducer`
  - `State` — `snapshot`(프로필 + 테마, 불러오기 전 `nil`) · `isLoading` · `alert`
    - `themeDisplayName` — 테마 행에 표시할 값. 불러오기 전에는 빈 문자열이라 화살표만 보인다
  - `Action.ViewAction` — `onAppear` · `editProfileButtonTapped` · `themeRowTapped` ·
    `notificationRowTapped` · `accountRowTapped` · `supportRowTapped` · `feedbackRowTapped` · `backButtonTapped`
  - `Action.Delegate` — 위 각 탭에 대응하는 `...Requested`. parent가 이걸 받아 화면을 띄운다
- `struct SettingView` — `init(store:)`

### 내부 구성 (`Sources/Components/`)

- `SettingProfileHeader` — 아바타 + 닉네임/이메일 + 편집 버튼
  - 디자인 시스템에 올리지 않았다. 재사용처가 이 화면 하나뿐인데 DS에 넣으면 검수앱 갤러리에
    Variant를 나열할 의무가 붙는다 (`.claude/rules/design-system.md`). 다른 화면에서도
    같은 블록이 필요해지면 그때 승격한다

## 시안 대비 알려진 차이

- **행 leading 아이콘 색** — Zeplin `List / Arrow` 컴포넌트 정의는 `Label.neutral`(#AEAFB4)인데
  설정 화면 인스턴스는 `Label.alternative`(#74767B)다. 검증이 화면 기준이라 화면을 따르고
  `CHALLAListRow`의 `iconColor` 오버라이드로 처리했다. **디자이너 확정 필요**
- **탑 내비게이션에 타이틀이 없다** — `CHALLATopNavigation.sub(title: "")`로 처리했다.
  DS에 타이틀 없는 variant를 추가할지는 디자이너 확인 후 판단
- **아바타 이미지를 아직 그리지 않는다** — `SettingProfile.avatarURL`을 받아두지만 화면은 항상
  기본 아바타(회색 실루엣)를 그린다. 이미지 로딩 모듈(#25 `CHALLAImageKit`)이 들어온 뒤 연결한다
- **테마 값 글자가 항상 노란색이다** — `CHALLAListRow`는 `.arrow(value:)`의 값을 `themeColor`로
  칠하고 기본값이 `CHALLAColor.defaultTheme`(yellow)인데, 여기서 넘기지 않는다.
  `AppTheme` → `Primary` 매핑의 시안 근거가 6쌍 중 2쌍뿐이라 임의로 만들지 않았다.
  지금은 저장된 테마가 늘 기본값(레몬에이드=yellow)이라 결과가 맞지만,
  **테마 선택 화면이 생기면 어긋난다** — 그 이슈에서 매핑 확정과 함께 처리한다

## 알려진 트레이드오프

**프로필 조회가 실패하면 실패할 일이 없는 로컬 테마까지 화면에 뜨지 못한다.**
`LoadSettingsUseCase.live`가 프로필을 먼저 `await`하고 거기서 throw하므로 `fetchTheme()`에
도달조차 하지 않고, `SettingsSnapshot`이 원격 값과 로컬 값을 한 덩어리로 묶어 통째로 비게 된다.
한 번에 모아 돌려줘야 화면이 두 번 갱신되며 깜빡이지 않는데, 그 이점은 성공 경로에만 해당한다.
부분 실패(테마는 보여주고 프로필만 재시도)로 바꾸려면 UseCase 반환 계약을 바꿔야 한다.

**불러오기에 실패하면 화면 안에서 재시도할 수 없다.** 얼럿 버튼이 "확인" 하나뿐이고,
`onAppear`가 `snapshot == nil`에서만 동작하므로 화면을 벗어났다 다시 들어와야 다시 시도된다.
재시도 버튼을 넣을지는 얼럿 문구 정책과 함께 정할 사안이다 (`SettingFeature.swift`의 TODO 참고).

## 의존 관계

- **이 모듈이 의존**: `SettingDomain` · `ComposableArchitecture` · `CHALLADesignSystem`
- **이 모듈에 의존**: `SettingFeatureDemo` (추후 `CHALLAApp`)

## 테스트 실행

```bash
xcodebuild -workspace CHALLA.xcworkspace -scheme SettingFeature \
  -destination 'platform=iOS Simulator,name=<시뮬레이터>' test
```

## 데모앱

```bash
xcrun simctl launch booted com.challa.settingfeature.demo --screen setting --state default
```

`--state`는 `default` · `loading` · `error`. 시안 검증(`zeplin-ui-verification`)이 이 인자로 각 상태를 캡처한다.
