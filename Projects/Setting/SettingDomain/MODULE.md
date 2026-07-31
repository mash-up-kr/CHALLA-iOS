# SettingDomain

## 레이어와 책임

**Domain 레이어**. 설정 화면과 그 하위 화면(테마 선택·알림)이 다루는 값을 정의한다 —
엔티티(값 타입), 저장소 인터페이스, Feature-facing UseCase.
서버·`UserDefaults`의 존재를 모르며 (import는 `Foundation` + `Dependencies`/`DependenciesMacros`뿐),
인터페이스 구현은 전부 `SettingData`가 맡는다 (아키텍처 규칙 1: `Feature → Domain ← Data`).

**색을 모른다.** `AppTheme`은 테마의 *정체*와 `displayName`까지만 책임진다.
Domain이 `CHALLADesignSystem`을 import하면 도메인이 UI에 묶이기 때문이다.

`AppTheme` → `CHALLAColor.Primary` 매핑은 **아직 어디에도 없다.** 시안에 근거가 있는 건
레몬에이드=yellow · 라즈베리=pink 둘뿐이라(`CHALLAListRow` 프리뷰) 나머지 넷을 임의로 정하지 않았다.
테마 선택 화면 이슈에서 여섯 쌍을 확정한 뒤 UI 레이어에 추가한다.

**의존 주입 설계**: `AuthDomain`과 같다 — UseCase는 `@DependencyClient` + `TestDependencyKey`로
선언하고 **`liveValue`를 두지 않는다.** 인자 없는 `liveValue`를 채우려면 구체 구현체를 만들어야 하고,
그러려면 Data를 import해야 해 규칙 2가 깨진다. 대신 `live(settings:profile:)`가 인터페이스만 받아
조립하고, 구현체를 넘기는 일은 실행 앱의 `CompositionRoot`가 맡는다.

## 공개 API

### Entities (`Sources/Entities/`)

- `enum AppTheme` — 기획이 정한 6종(`lemonade` · `raspberry` · `orange` · `cider` · `blueberry` · `acaiBowl`)
  - `displayName` — 설정 화면 테마 행에 값으로 표시되는 이름 (`레몬에이드` 등)
  - `AppTheme.default` — `.lemonade`. 고른 적 없는 사용자에게 적용
  - `CaseIterable` — 테마 선택 화면이 `allCases`로 목록을 그린다
  - `Codable` · `RawRepresentable(String)` — 로컬 저장에 `rawValue`를 쓴다
- `struct NotificationSetting` — `isServiceEnabled`(인화 대기·완료 등 서비스 알림)
  - `NotificationSetting.default` — 꺼짐. 시안의 기본 상태가 OFF다
  - 항목이 늘어날 것을 대비해 `Bool` 하나가 아니라 구조체로 둔다
- `struct SettingProfile` — `nickname` · `email` · `avatarURL`
  - **임시 모델이다.** 프로필 정본은 이슈 #33의 `UserProfile`이며, 머지되면 이 타입을 지우고 교체한다
  - `email`은 시안에 `juy***@naver,com`처럼 마스킹되어 나온다. 마스킹 주체(서버/클라이언트)가
    미정이라 받은 문자열을 그대로 표시한다
- `struct SettingsSnapshot` — `profile` + `theme`. 화면이 두 번 갱신되어 깜빡이지 않도록 한 번에 모아 돌려준다

### Errors

- `enum SettingError` — `.network` · `.profileUnavailable` · `.unknown`
  - `userMessage` — 얼럿용 문구 (기획 정책 확정 전 임의 작성본)

### Interface (`Sources/Interface/`)

- `protocol SettingsRepository` (구현: `SettingData`) — 테마·알림
  - `fetchTheme() async -> AppTheme` / `updateTheme(_:) async`
  - `fetchNotificationSetting() async -> NotificationSetting` / `updateNotificationSetting(_:) async`
  - 로컬 저장이라 실패 개념이 없어 던지지 않는다. 값이 없으면 각 타입의 `default`를 돌려준다
- `protocol SettingProfileProvider` (구현: 합성 지점) — 프로필
  - `fetchProfile() async throws -> SettingProfile`
  - **`SettingsRepository`와 분리한 이유**: 프로필은 설정과 다른 aggregate다.
    `.claude/rules/architecture.md`가 "Domain·Data는 화면 단위가 아니라 aggregate 단위로 1벌만
    만든다"고 정하고 있고, 프로필의 정본은 이슈 #33의 `UserRepository`다. 여기서 조회를 또
    구현하면 같은 서버 계약이 두 곳에 생긴다. 설정 쪽은 필요한 모양만 선언하고,
    #33 머지 후 어댑터만 `CompositionRoot`에 두면 Domain·Feature는 손댈 게 없다

### UseCases (`Sources/UseCases/`)

- `struct LoadSettingsUseCase` — 설정 화면 진입 시 프로필과 테마를 함께 불러온다
  - `live(settings:profile:)` — 조립용 팩토리 (`liveValue` 없음, 위 설명 참고).
    의존성을 인터페이스로만 받는 형태는 `LoginUseCase.live(social:repository:tokenStore:)`와 같다
  - `previewValue` — 시안 문구가 담긴 스텁
  - `DependencyValues.loadSettingsUseCase`로 접근

> 테마·알림을 **변경**하는 UseCase는 하위 화면(테마 선택·알림) 이슈에서 추가한다.
> 설정 화면 자체는 값을 표시만 하고 바꾸지 않는다.

## 의존 관계

- **이 모듈이 의존**: `Dependencies` · `DependenciesMacros` (swift-dependencies, TCA 전이 의존)
- **이 모듈에 의존**: `SettingData`(인터페이스 구현) · `SettingFeature`(UseCase 사용)

## 테스트 실행

```bash
xcodebuild -workspace CHALLA.xcworkspace -scheme SettingDomain \
  -destination 'platform=iOS Simulator,name=<시뮬레이터>' test
```

`xcrun simctl list devices available`로 설치된 기기 이름을 먼저 확인한다.
