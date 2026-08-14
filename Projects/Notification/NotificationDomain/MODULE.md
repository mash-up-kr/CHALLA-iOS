# NotificationDomain

## 레이어와 책임

**Domain 레이어**. FCM 디바이스 토큰을 서버에 등록·해제하는 계약만 정의한다.
구현은 `NotificationData`, 조립은 실행 앱의 `CompositionRoot`가 맡는다.

**설정 화면의 '서비스 알림' 토글이 이 두 API로 처리된다** — 켜면 `register`, 끄면 `unregister`.

서버에 알림 on/off 값을 저장하는 API가 따로 없어서다. 대신 서버는 등록된 토큰이 있는 기기에만
푸시를 보내므로, 토큰을 넣고 빼는 것으로 같은 효과를 낸다.

## 공개 API

- `protocol PushTokenRepository`
  - `register(token:)` — 이 기기 토큰을 내 계정에 등록. 같은 토큰 재등록도 안전하다
  - `unregister(token:)` — 로그아웃 · 탈퇴 · 알림 끄기에서 호출.
    해제하지 않으면 같은 기기에 다른 계정으로 로그인해도 이전 계정 푸시가 온다
  - `sendTestPush(title:body:)` → `Int` — **`#if DEBUG`.** 내 계정의 모든 토큰으로 발송하고
    성공한 토큰 수를 돌려준다. 개발 중 수신 확인용이라 릴리스 빌드에는 넣지 않는다.
    `0`이면 등록된 토큰이 없다는 뜻이라 등록 성공 여부를 이걸로 판별한다
- `enum NotificationError` — `.network` · `.unauthorized` · `.server(message:)` · `.unknown`

## UseCase를 두지 않는 이유

다른 aggregate는 Feature가 `@Dependency`로 꺼내 쓸 UseCase를 두지만, 여기는 두지 않았다.
토큰 등록·해제를 호출하는 곳이 Feature가 아니라 실행 앱(`AppDelegate`, `CompositionRoot`)뿐이고,
App은 Data를 직접 import 할 수 있어 Repository를 그대로 쓰면 된다.
Feature가 이 흐름을 필요로 하게 되면 그때 UseCase를 추가한다.

설정 화면의 토글은 이미 `SettingDomain.UpdateServiceNotificationUseCase`를 통해 들어온다 —
실행 앱이 그 UseCase의 live 값을 "로컬 저장 + 토큰 동기화"로 조립한다.

## `userMessage`가 없는 이유

토큰 등록·해제는 사용자가 시작하지 않은 배경 동작이라 실패를 보여줄 화면이 없다.
실패하면 다음 실행의 재동기화가 바로잡는다 (`CHALLAApp`의 `PushTokenSynchronizer`).

## 테스트가 없는 이유

프로토콜과 오류 enum뿐이라 검증할 로직이 없다.
서버 계약(경로 · 메서드 · envelope 모양)과 오류 정규화는 `NotificationData`의 테스트가 고정한다.

## 의존 관계

- **이 모듈이 의존**: 없음 (Foundation만)
- **이 모듈에 의존**: `NotificationData` · `CHALLAApp`
