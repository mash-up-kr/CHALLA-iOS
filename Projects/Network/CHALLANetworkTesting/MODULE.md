# CHALLANetworkTesting

## 레이어와 책임

**Network 레이어의 테스트 전용 지원 모듈.** 각 Data 모듈 테스트가 공유하는 `MockHTTPClient` 하나만 담는다.
`CHALLANetwork`의 `HTTPClient`를 목으로 구현해, Repository가 올바른 `Endpoint`를 골라 서버 계약대로 요청을 실었는지 검증한다.

테스트 타깃만 의존하므로 **앱 번들에는 포함되지 않는다.** 예전에는 AuthData·UserData·NotificationData·RoomData가
같은 목을 각자 복사해 뒀는데(#51), 이 모듈로 한 벌만 두고 재사용한다.

## 공개 API

- `final class MockHTTPClient: HTTPClient`
  - `init(results:)` / `init(result:)` — 호출 순서대로 소비하고, 다 쓰면 마지막 값을 반복한다.
  - `var requests: [CapturedRequest]` — 전송된 요청 스냅샷 (호출 순서대로).
  - `static returning(statusCode:json:)` · `static failing(_:)` · `static succeeding(_:)` — 목 생성 편의.
- `struct CapturedRequest` — `path` · `method` · `headers` · `usesBearerToken` · `body` · `queryItems`.

## 의존성

- 의존: `CHALLANetwork`
- 이 모듈에 의존: `AuthDataTests` · `UserDataTests` · `NotificationDataTests` · `RoomDataTests`

## 테스트 실행 방법

자체 테스트는 없다(테스트 지원 코드만 담는다). 이 목을 쓰는 Data 모듈 테스트가 `tuist test`로 함께 돌아간다.
