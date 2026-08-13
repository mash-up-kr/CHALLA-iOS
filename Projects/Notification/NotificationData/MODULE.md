# NotificationData

## 레이어와 책임

**Data 레이어**. `NotificationDomain.PushTokenRepository`를 알림 서버 호출로 구현한다.
Endpoint · DTO · 오류 매핑은 전부 `internal`이고, 밖으로 여는 것은 어댑터 하나뿐이다.

의존성 등록은 하지 않는다 — 구현체만 내놓고 조립은 실행 앱의 `CompositionRoot`가 맡는다.

## 공개 API

- `struct DefaultPushTokenRepository: PushTokenRepository` — `init(client: any HTTPClient)`.
  client는 Auth · User와 **같은 인스턴스**를 받아야 한다.
  다른 걸 넘기면 `AuthInterceptor`가 붙인 토큰이 실리지 않아 401이 난다

## 서버 계약

셋 다 `bearerAuth`이고 요청 본문을 `notification` 키로 한 번 감싼다.

| 메서드 | 경로 | 본문 | 응답 |
| :-- | :-- | :-- | :-- |
| POST | `/api/v1/notifications/tokens` | `{ notification: { token } }` | `{ success, message }` |
| DELETE | `/api/v1/notifications/tokens` | `{ notification: { token } }` | `{ success, message }` |
| POST | `/api/v1/notifications/test` | `{ notification: { title, body } }` | `+ data.notification.sentCount` |

- **해제도 본문으로 토큰을 받는다** — query 파라미터가 아니다
- 등록·해제 응답에는 `data` 키가 아예 없다. `BaseResponseDTO.data`가 옵셔널이라 없어도 디코딩되고,
  `ensureSuccess()`로 성공 여부만 본다
- `sendTestPush`는 서버에 FCM 자격증명이 없으면 500이 난다 — 서버 설정 확인에도 쓸 수 있다

## `BaseResponseDTO` 세 번째 사본

`AuthData` · `UserData`에 같은 타입이 있고 이게 세 번째다. `unwrap`이 던지는 오류 타입만
aggregate마다 다르고 나머지는 같다. 공용 모듈로 올릴 시점이지만, 오류 타입을 제네릭으로 빼면서
세 Data 모듈을 함께 고쳐야 해 이 이슈 범위를 넘는다 — **별도 이슈로 승격한다.**

## 테스트 실행

```bash
xcodebuild -workspace CHALLA.xcworkspace -scheme NotificationData \
  -destination 'platform=iOS Simulator,id=<UDID>' test
```

기기 이름은 런타임마다 중복되므로 `xcrun simctl list devices available`로 UDID를 확인해 쓴다.

테스트는 라우팅 계약(경로 · 메서드 · bearer 여부 · 본문 모양)과 오류 정규화를 고정한다.
`Tests/Support/MockHTTPClient`는 `UserData`의 것과 같은 구현이다.

## 의존 관계

- **이 모듈이 의존**: `NotificationDomain` · `CHALLANetwork`
- **이 모듈에 의존**: `CHALLAApp`
