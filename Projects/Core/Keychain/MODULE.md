# Keychain

## 레이어와 책임

**Core 레이어** (OS 접점). iOS Keychain(Security 프레임워크)을 감싼 키-값 보안 저장소 모듈이다.
토큰 등 민감한 값을 `kSecClassGenericPassword` 항목으로 저장·조회·삭제하는 최소 API만 제공하며,
"무엇을 어떤 키로 저장할지"는 사용하는 쪽(Data 레이어)이 정한다.

인터페이스(`Keychain`)와 구현(`KeychainStore`)을 분리해 상위 레이어가 테스트에서 목으로 대체할 수 있다.
SecItem API가 동기이므로 이 모듈의 API도 동기다 — async 경계는 상위 레이어가 담당한다
(예: `AuthData`의 `TokenProvider.accessToken()`).

**동시성**: 공개 타입은 모두 `Sendable`이다 (`@unchecked` 미사용). `KeychainStore`는
불변 `service` 하나만 갖는 final class라 `Sendable`이 자연 성립하며, Swift 6 strict concurrency에서
경고 없이 컴파일된다.

## 공개 API

### 인터페이스
- `protocol Keychain: Sendable`
  - `save(_ data: Data, for key: String) throws` — 같은 키가 있으면 덮어쓴다
  - `load(for key: String) throws -> Data?` — 미존재 키는 `nil` (오류 아님)
  - `delete(for key: String) throws` — 미존재 키 삭제도 성공으로 간주
- String 편의 확장 — `saveString(_:for:)` · `loadString(for:)` (UTF-8 변환 후 위 API에 위임)

### 구현 · 오류
- `final class KeychainStore: Keychain` — `init(service:)`. `service`가 항목의 네임스페이스가 되고
  `key`는 `kSecAttrAccount`에 대응한다. 저장 시 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 접근 정책을 명시해
  토큰 등 백그라운드 접근이 필요한 항목을 저장한다 (백업/iCloud 이전 제외, 이 기기 한정).
  시뮬레이터·실기기 모두 동작 (키체인 공유 그룹 미사용)
  - `save`는 **`SecItemUpdate` 후 없으면 `SecItemAdd`**(upsert)로 동작한다. 지우고 다시 넣는 방식이 아닌 이유:
    삭제만 성공하고 추가가 실패하면 원래 값까지 사라져(토큰 소실 → 강제 재로그인) 실패가 값 유실로 번진다.
    update는 실패해도 기존 값이 그대로 남는다
- `enum KeychainError` — `.unexpectedStatus(OSStatus)` · `.dataConversionFailed`

## 사용 예시 (Data 레이어)

```swift
import Keychain

let keychain = KeychainStore(service: "com.challa.auth")
try keychain.saveString(sessionID, for: "challa.auth.sessionID")
let sessionID = try keychain.loadString(for: "challa.auth.sessionID")
try keychain.delete(for: "challa.auth.sessionID")
```

> 함께 갱신돼야 하는 값들을 여러 키로 나눠 저장하지 말 것. 키체인에는 트랜잭션이 없어서
> 앞의 저장만 성공하면 값끼리 어긋난 상태가 남는다. 한 항목에 묶어 한 번에 쓰면 그 중간 상태가 없다
> (예: `AuthData`의 `KeychainTokenStore`가 access·refresh를 한 항목으로 저장한다).

## 의존성

- **이 모듈이 의존**: 없음 (`Foundation` · `Security`만 사용, 외부 패키지 0)
- **이 모듈에 의존**: `AuthData` (토큰 저장소 `KeychainTokenStore`) · 이후 민감값 저장이 필요한 Data 모듈들

## 테스트 실행 방법

```bash
mise exec -- tuist test Keychain
```

Swift Testing 기반 테스트 11개 — `KeychainStoreTests` (저장·조회 라운드트립, 미존재 키 `nil`, 삭제 후 `nil`,
덮어쓰기, upsert 경로별 항목 수(첫 저장은 생성 · 재저장은 중복 생성 없음), service 격리,
String 편의 확장, 비-UTF-8 오류).
각 테스트는 고유 `service` 이름을 쓰고 끝에 항목을 정리해 서로 간섭하지 않는다.

`.unexpectedStatus(OSStatus)` 경로는 실제 SecItem에서 오류를 강제할 수 없어 이 모듈에서는 검증하지 않는다.
저장 실패 시의 상위 동작은 목(`MockKeychain`)을 쓰는 `AuthData` 테스트가 덮는다.

**중요**: SecItem API는 앱 엔타이틀먼트가 있어야 접근 가능하므로, 테스트는 `KeychainTestHost`라는
빈 호스트 앱에 태워 실행된다. 호스트 없이 시뮬레이터 일반 테스트 러너로 돌리면 `errSecMissingEntitlement(-34018)`로
전부 실패한다. Tuist가 자동으로 호스트 앱을 테스트 대상(Dependencies)에 주입하므로 개발자가 별도 설정할 필요는 없다.
