# SettingData

## 레이어와 책임

**Data 레이어**. `SettingDomain`이 정의한 `SettingsRepository`를 구현한다
(아키텍처 규칙 1: `Feature → Domain ← Data`).

테마와 알림 설정을 기기에 저장하고 다시 읽는 일을 한다. **네트워크 의존이 없다.**

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

## 의존 관계

- **이 모듈이 의존**: `SettingDomain`
- **이 모듈에 의존**: 실행 앱의 `CompositionRoot`(`SettingFeatureDemo`, 추후 `CHALLAApp`)
  — Feature는 이 모듈을 import 하지 않는다 (규칙 2)

## 테스트 실행

```bash
xcodebuild -workspace CHALLA.xcworkspace -scheme SettingData \
  -destination 'platform=iOS Simulator,name=<시뮬레이터>' test
```
