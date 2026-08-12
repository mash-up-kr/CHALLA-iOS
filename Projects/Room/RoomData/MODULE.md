# RoomData

## 레이어와 책임

**Data 레이어**. `RoomDomain`의 `RoomRepository`를 구현한다. 서버 API가 확정되기 전까지 쓰는
메모리 저장소와, 데모앱·검수용 시드 데이터를 담는다.

**지금은 서버를 부르지 않는다.** 방 API 스펙이 없어 `InMemoryRoomRepository` 하나만 있고
`CHALLANetwork` 의존도 없다. 스펙이 나오면 `DefaultRoomRepository`(HTTPClient 호출 + DTO 변환 +
`RoomError` 매핑)를 새로 만들고 합성 루트의 조립 한 줄만 바꾼 뒤 메모리 저장소를 지운다.
`RoomRepository` 프로토콜이 그대로라 `RoomDomain`과 `HomeFeature`는 손대지 않는다.

## 공개 API

### Repository (`Sources/Repository/`)

- `actor InMemoryRoomRepository: RoomRepository`
  - `init(rooms:inviteCodes:latency:failure:)` — 시작 목록, 초대 코드→방 id 매핑,
    응답 지연, 심어 둘 오류
  - `latency`·`failure`는 데모앱이 로딩·실패 화면을 재현하는 수단이다
  - 초대 코드는 `Room`에 없어(홈 카드가 쓰지 않는다) 저장소가 코드→방 매핑을 따로 들고 있다

**`actor`인 이유**: 방 목록이 계속 바뀌는데 `RoomRepository`는 `Sendable`이라 동시 접근이 안전해야 한다.
락으로 묶는 방법도 있으나 `await`로 기다리는 구간이 있어 쓸 수 없다(락은 스레드를 붙잡고 `await`는 놓는다).
대신 actor는 재진입을 허용하므로 — `await`에서 멈춘 사이 다른 호출이 상태를 바꿀 수 있다 —
세 메서드 모두 기다리는 일을 `waitAndCheckFailure()`로 앞에 모으고 그 뒤로는 `await` 없이 상태를 읽고 쓴다.

### Sample (`Sources/Sample/`)

- `enum RoomSamples` — `inviteCode`(시안의 `1928121`) · `inviteCodes` ·
  `shootingOnly` · `completedOnly` · `mixed`
  - 목록 구성이 데모앱의 화면 상태와 1:1로 대응한다
  - `Room.previewXxx`(Domain)와 용도가 다르다 — 그쪽은 `#Preview`용이라 네트워크 없이 즉시 그려져야 해
    사진이 비어 있고, 이쪽은 실행 중이라 사진을 받아올 수 있다. 사진이 없으면 인화 카드의
    낱장 스택과 "+N" 오버레이를 시안과 대조할 수 없다
  - 사진은 picsum 시드 URL이라 시드가 같으면 항상 같은 사진이 온다 (검수할 때마다 화면이 달라지지 않는다)

## 의존성

- **이 모듈이 의존**: `RoomDomain` (인터페이스·엔티티·오류)
- **이 모듈에 의존**: `HomeFeatureDemo` · `CHALLAApp` — 합성 루트만 import한다
  (아키텍처 규칙 2: Feature는 Data를 import하지 않는다)

## 테스트 실행 방법

```bash
mise exec -- tuist test RoomData
```

Swift Testing 기반 순수 유닛테스트(시뮬레이터 불필요).

- `InMemoryRoomRepositoryTests` — 시작 목록 순서 유지, 생성 시 서버 몫 값(id·상태·인원수)을
  저장소가 채우는지, 만든 방이 목록에 남고 최근 방이 맨 앞에 오며 id가 서로 다른지,
  입장 시 인원 증가가 목록에도 반영되는지, 없는 코드의 `.roomNotFound`,
  `failure`를 심으면 세 메서드가 모두 그 오류를 던지는지

`RoomSamples`는 값 선언뿐이라 테스트하지 않는다.
