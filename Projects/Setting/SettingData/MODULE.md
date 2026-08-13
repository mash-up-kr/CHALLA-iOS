# SettingData

## 레이어와 책임

**Data 레이어**. `SettingDomain`이 정의한 인터페이스(`SettingsRepository` ·
`NotificationPermissionProvider` · `AccountRepository`)를 구현한다
(아키텍처 규칙 1: `Feature → Domain ← Data`).

테마와 알림 설정을 기기에 저장하고 다시 읽으며, 시스템 알림 권한을 조회한다.
**네트워크 의존이 없다** — 테마·알림은 기기 저장이고, 프로필·계정은 다른 aggregate라
실행 앱의 어댑터가 잇는다 (`CHALLAApp/Sources/Adapters/`).

## 프로필은 왜 여기 없나

이슈 #35의 TO-DO에는 "프로필 조회는 CHALLANetwork 연동"이라 적혀 있지만 그렇게 하지 않았다.
근거는 `.claude/rules/architecture.md`다 — **"Domain·Data는 화면 단위가 아니라 aggregate 단위로
1벌만 만든다."** 프로필(User)과 설정(테마·알림)은 다른 aggregate이고, 프로필의 정본은
**이슈 #33의 `UserRepository`**다.

여기서 같은 호출을 또 만들면:
- 같은 서버 계약이 두 곳에 생기고, #33 머지 때 한쪽을 지워야 한다
- 응답 디코딩에 `BaseResponseDTO`가 필요한데 그 파일에는
  *"다른 Data 모듈도 같은 DTO를 쓰게 되면 공용 모듈로 승격한다 — 그전까지 복붙 금지"* 라고
  명시돼 있다 (`Projects/Auth/AuthData/Sources/DTO/BaseResponseDTO.swift`).
  승격은 `AuthData`를 건드리는 일이라 PR #32가 열려 있는 지금 할 작업이 아니다

그래서 프로필은 `SettingDomain`의 `SettingProfileProvider` protocol이 맡고, 이 모듈은 관여하지 않는다.
#33이 머지되면 `UserRepository`를 그 protocol에 맞춰주는 어댑터를 `CompositionRoot`에 두면 된다.

## 공개 API

### Storage (`Sources/Storage/`)

- `protocol SettingsStorage` — 설정 값을 담아두는 키-값 저장소 추상
  (`UserDefaults`를 직접 쓰면 테스트끼리 상태가 새서 한 겹 둔다)
- `struct UserDefaultsSettingsStorage` — `UserDefaults` 기반 구현
  - `bool(forKey:)`가 `Bool?`를 돌려준다 — "설정한 적 없음"과 "꺼둠"을 구분해야
    Domain의 기본값 규칙을 적용할 수 있다

### Repository (`Sources/Repository/`)

- `struct DefaultSettingsRepository: SettingsRepository`
  - `init(storage:)` — 저장소를 주입받는다 (기본값 `UserDefaultsSettingsStorage()`)
  - 저장 키: `challa.setting.theme` · `challa.setting.notification.service`
  - 알 수 없는 테마 문자열이 저장돼 있으면(앱 다운그레이드·수동 조작) `AppTheme.default`로 떨어진다

### System (`Sources/System/`)

- `struct SystemNotificationPermissionProvider: NotificationPermissionProvider`
  - `UNUserNotificationCenter`로 권한을 읽고 `UIApplication`으로 설정 앱을 연다.
    iOS 16+ `openNotificationSettingsURLString`을 먼저 시도하고 안 되면 앱 설정 루트로 떨어진다
  - `requestAuthorization()`은 배너 문구("앱 알림이 꺼져있어요")에 맞춰 alert·sound·badge를 한 묶음으로 요청하고,
    granted 플래그가 아니라 **다시 읽은 실제 상태**를 돌려준다 (`.provisional`처럼 granted가 false인 허용 상태를 놓치지 않는다)
  - 권한을 받은 뒤 원격 알림에 등록하는 일(FCM 토큰 발급)은 여기서 하지 않는다 —
    실행 앱의 `CompositionRoot`가 이 구현을 감싸 이어붙인다
  - `UNNotificationSettings`가 `Sendable`이 아니라, 콜백 안에서 `UNAuthorizationStatus`만 꺼내
    `withCheckedContinuation`으로 넘긴다
  - **Core가 아니라 여기 있는 이유**: OS를 만지면 Core가 원칙이지만 이 모듈은 이미 `UserDefaults`를
    만지고 있고 사용처가 이 화면 하나뿐이다. 다른 모듈에서 같은 접근이 필요해지면
    Core 모듈로 승격한다 — Domain 인터페이스가 그대로라 Feature는 안 바뀐다

## 의존 관계

- **이 모듈이 의존**: `SettingDomain`
- **이 모듈에 의존**: 실행 앱의 `CompositionRoot`(`SettingFeatureDemo`, 추후 `CHALLAApp`)
  — Feature는 이 모듈을 import 하지 않는다 (규칙 2)

## 테스트 실행

```bash
xcodebuild -workspace CHALLA.xcworkspace -scheme SettingData \
  -destination 'platform=iOS Simulator,name=<시뮬레이터>' test
```
