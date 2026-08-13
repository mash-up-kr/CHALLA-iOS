# SettingDomain

## 레이어와 책임

**Domain 레이어**. 설정 화면과 그 하위 화면(테마 선택·알림)이 다루는 값을 정의한다 —
엔티티(값 타입), 저장소 인터페이스, Feature-facing UseCase.
서버·`UserDefaults`의 존재를 모르며 (import는 `Foundation` + `Dependencies`/`DependenciesMacros`뿐),
인터페이스 구현은 전부 `SettingData`가 맡는다 (아키텍처 규칙 1: `Feature → Domain ← Data`).

**색을 모른다.** `AppTheme`은 테마의 *정체*와 `displayName`까지만 책임진다.
Domain이 `CHALLADesignSystem`을 import하면 도메인이 UI에 묶이기 때문이다.

`AppTheme` → `CHALLAColor.Primary` 매핑은 **`SettingFeature`에 있다**
(`Sources/Support/AppTheme+ThemeColor.swift`). Domain은 UI를 모르고 DS는 Domain을 모르므로
둘 다 아는 레이어가 Feature뿐이다. 앱 전체 테마 적용이 생기면 공용 위치로 승격한다.

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
- `struct SettingProfile` — `nickname` · `avatarURL`
  - 프로필 정본은 `UserDomain.UserProfile`이지만 그 타입을 여기서 쓰지 않는다 —
    다른 aggregate라 `SettingDomain`이 `UserDomain`에 의존하게 된다.
    실행 앱의 `CompositionRoot`가 `UserProfile` → 이 타입으로 옮기는 어댑터를 주입한다
  - **이메일 필드가 없다.** 시안에는 있지만 서버가 내려주지 않는다
    (`GET /api/v1/users/me` 응답은 `id · nickname · profileImageUrl`뿐)
- `enum NotificationAuthorizationStatus` — `.notDetermined` · `.denied` · `.authorized`
  - `UNAuthorizationStatus`를 그대로 두지 않고 화면이 필요로 하는 셋으로 좁힌다.
    `.provisional`·`.ephemeral`은 `.authorized`로 접는다 (알림이 오는 상태에서 "꺼져있어요" 배너를 띄우면 안 된다)
- `struct NotificationSettingsSnapshot` — `setting` + `authorization`.
  둘 다 즉시 돌아오고 **실패 경로가 없어** 한 묶음으로 둔다
  (실패할 수 있는 값과는 묶지 않는다 — 아래 "프로필과 테마를 왜 따로 읽나" 참고)

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
    실행 앱의 `SettingProfileProviderAdapter`가 `UserRepository`를 이 protocol에 맞춰준다
- `protocol NotificationPermissionProvider` (구현: `SettingData`) — 시스템 알림 권한
  - `authorizationStatus() async -> NotificationAuthorizationStatus` — **권한을 요청하지는 않는다**
  - `requestAuthorization() async -> NotificationAuthorizationStatus` — 권한을 요청하고 결과 상태를 돌려준다.
    `.notDetermined`에서만 OS 팝업이 뜨고, 이미 정해진 상태에서는 현재 값이 그대로 온다
  - `openSystemNotificationSettings() async` — 설정 앱의 이 앱 화면을 연다. 실패하면 조용히 무시
- `protocol AccountRepository` — 로그아웃·회원 탈퇴
  - `signOut() async throws` / `deleteAccount() async throws`
  - 실패는 `SettingError`로 정규화해 던진다.
  - 구현은 `SettingData`가 아니라 실행 앱의 `AccountRepositoryAdapter`다 —
    로그아웃은 Auth aggregate, 탈퇴는 User aggregate라 둘을 조합하는 이 동작에 단일 Domain 홈이 없다

### UseCases (`Sources/UseCases/`)

모두 `@DependencyClient` + `TestDependencyKey`이고 **`liveValue`가 없다.**
`live(...)` 팩토리가 인터페이스만 받아 조립하고, 구현체 주입은 실행 앱의 `CompositionRoot`가 맡는다.
`DependencyValues`의 접근자 이름은 타입 이름을 lowerCamelCase로 바꾼 것이다(`loadThemeUseCase` 등).

| UseCase | 시그니처 | live 조립 |
| :-- | :-- | :-- |
| `LoadProfileUseCase` | `() async throws -> SettingProfile` | `.live(profile:)` |
| `LoadThemeUseCase` | `() async -> AppTheme` | `.live(settings:)` |
| `SelectThemeUseCase` | `(AppTheme) async -> Void` | `.live(settings:)` |
| `LoadNotificationSettingsUseCase` | `() async -> NotificationSettingsSnapshot` | `.live(settings:permission:)` |
| `UpdateServiceNotificationUseCase` | `(Bool) async -> Void` | `.live(settings:)` |
| `OpenSystemNotificationSettingsUseCase` | `() async -> Void` | `.live(permission:)` |
| `SignOutUseCase` | `() async throws -> Void` | `.live(account:)` |
| `DeleteAccountUseCase` | `() async throws -> Void` | `.live(account:)` |

- 테마·알림 계열은 로컬 저장이라 **던지지 않는다** — 실패 개념이 없다
- `UpdateServiceNotificationUseCase`가 `NotificationSetting` 전체가 아니라 `Bool`을 받는 이유:
  지금 항목이 하나뿐이라 화면이 다른 필드를 알 필요가 없다. 항목이 늘면 시그니처를 넓힌다
- 파일은 화면 단위로 묶는다(`ThemeUseCases` · `NotificationUseCases` · `AccountUseCases`).
  1파일 1UseCase면 파일이 8개로 흩어져 탐색 비용이 더 크다. `LoadProfileUseCase.swift`만 단독 파일이다

### 프로필과 테마를 왜 따로 읽나

**실패 가능성이 다른 값은 한 묶음으로 돌려주지 않는다.**
예전에는 `LoadSettingsUseCase`가 프로필(원격·실패 가능)과 테마(로컬·실패 불가)를 `SettingsSnapshot`
하나로 묶어 줬는데, 프로필 조회가 실패하면 스냅샷이 통째로 비어 **저장된 테마까지 사라졌다.**
설정 화면은 기본 테마를 표시하고, 그 값을 시드로 받는 알림 화면은 토글 색까지 틀리게 그렸다.

지금은 `LoadProfileUseCase`와 `LoadThemeUseCase`를 화면이 각각 호출한다.
테마는 로컬이라 즉시 돌아와 깜빡임도 없다.

## 의존 관계

- **이 모듈이 의존**: `Dependencies` · `DependenciesMacros` (swift-dependencies, TCA 전이 의존)
- **이 모듈에 의존**: `SettingData`(인터페이스 구현) · `SettingFeature`(UseCase 사용)

## 테스트 실행

```bash
xcodebuild -workspace CHALLA.xcworkspace -scheme SettingDomain \
  -destination 'platform=iOS Simulator,name=<시뮬레이터>' test
```

`xcrun simctl list devices available`로 설치된 기기 이름을 먼저 확인한다.
