# RoomData

## 레이어와 책임

**Data 레이어**. `RoomDomain`의 `RoomRepository`를 두 가지로 구현한다 (#54부터).

- `DefaultRoomRepository` — **실서버 구현.** `CHALLANetwork`의 `HTTPClient`로 방 API를 부르고,
  DTO를 도메인 타입으로, 네트워크 실패를 `RoomError`로 번역한다. 실배포앱이 쓴다
- `InMemoryRoomRepository` — **메모리 구현.** 카드를 배열에 들고 있어 앱을 끄면 사라진다.
  데모앱이 네트워크 없이 화면을 단독 실행하는 수단이라 실서버 구현이 생겨도 지우지 않는다

프로토콜이 같으므로 어느 쪽을 쓸지는 합성 루트가 정한다 — `CHALLAApp`은 Default를,
`HomeFeatureDemo`는 InMemory를 꽂는다. Feature는 차이를 모른다.

## 공개 API

### Repository (`Sources/Repository/`)

- `struct DefaultRoomRepository: RoomRepository` — `init(client:)`
  - 모든 메서드가 같은 흐름: 요청 → 껍데기 언랩 → 도메인 변환 → 실패 정규화(`RoomError.normalized`)
  - 상세(`roomInfo`)·참여자(`members`)는 경로가 방을 가리키는 GET — 없는 방 404는 `.roomNotFound`
  - `rooms()`는 세 상태를 전부 배열 쿼리(`?status=A&status=B&status=C`)로 요청한다 —
    상태 필터가 최소 1개 필수(생략 시 400)이고, 홈은 두 섹션을 한 화면에 그린다
  - `shootableRooms()`는 `GET /rooms/shootable`을 그대로 옮긴다 (촬영 가능 판단은 서버 몫)
  - 생성·입장은 서버 응답이 `{ id }`뿐이라 **목록을 재조회해 그 id의 카드를 돌려준다**
    (`card(withID:)`에 격리 — 백엔드가 응답에 방 전체를 실어주면 이 메서드만 지운다)
  - 확인 기록(`checkPrintCompletion`)·이름 변경(`updateTitle`)은 PUT — 응답 data가 비어 있어
    (`EmptyResponseDTO`) 껍데기 성공 여부만 확인하고 돌려줄 것이 없다
  - 상태 없는 `struct`다 — 진짜 데이터가 전부 서버에 있고 이 타입은 통로라 actor가 필요 없다
- `actor InMemoryRoomRepository: RoomRepository`
  - `init(cards:inviteCodes:membersByRoom:latency:failure:)` — 시작 목록, 초대 코드→방 id 매핑,
    방별 참여자, 응답 지연, 심어 둘 오류
  - `latency`·`failure`는 데모앱이 로딩·실패 화면을 재현하는 수단이다
  - 상세의 초대 코드는 입장용 매핑을 거꾸로 찾고, 매핑에 없는 방(데모의 방 만들기로 생성)은
    발급할 서버가 없어 id로 일곱 자리를 지어낸다. 참여자는 `membersByRoom` 주입 구성 그대로
  - `shootableRooms()`는 들고 있는 카드 중 촬영 중 상태만 축약형으로 내려준다 (실서버 기준을 흉내)
  - 방 생성 id는 음수 카운터(-1000부터 감소) — 서버는 양수만 주므로 음수 = 서버가 발급하지 않은
    데이터라는 표식. 프리뷰(-1~-3)·샘플(-10번대)과 겹치지 않는다
  - 확인 기록·이름 변경은 들고 있는 카드를 새 값으로 바꿔 재현한다 — 실서버가 다음 목록
    조회에 반영해 주는 것과 같은 모습이다

**`actor`인 이유** (InMemory): 방 목록이 계속 바뀌는데 `RoomRepository`는 `Sendable`이라 동시 접근이
안전해야 한다. 락으로 묶는 방법도 있으나 `await`로 기다리는 구간이 있어 쓸 수 없다(락은 스레드를 붙잡고
`await`는 놓는다). 대신 actor는 재진입을 허용하므로 — `await`에서 멈춘 사이 다른 호출이 상태를 바꿀 수
있다 — 모든 메서드가 기다리는 일을 `waitAndCheckFailure()`로 앞에 모으고 그 뒤로는 `await` 없이
상태를 읽고 쓴다.

- `struct DefaultPrintNoticeRepository: PrintNoticeRepository` — `init(storage:)`
  - 인화 완료 안내를 봤는지 방마다 기기에 저장한다 (`challa.room.printNotice.seen.<roomID>`).
    서버가 아니라 기기에 남기는 이유는 `RoomDomain.PrintNoticeRepository` 주석 참고
  - 방마다 키를 하나씩 쓴다 — 한 키에 방 목록을 모으면 읽고 쓸 때마다 목록을 갈아 끼워야 해
    Bool 하나짜리 기록에는 과하다. 방이 지워져도 기록은 남지만 키 하나가 Bool 하나라 무시할 수 있다
- `actor InMemoryPrintNoticeRepository: PrintNoticeRepository` — `init(seenRoomIDs:)`
  - 데모·테스트용. 앱을 끄면 사라져 매번 안내부터 다시 볼 수 있다

### Storage (`Sources/Storage/`)

- `protocol PrintNoticeStorage` — `bool(forKey:)` · `setBool(_:forKey:)`
- `struct UserDefaultsPrintNoticeStorage: PrintNoticeStorage` — `init(defaults:)`
  - `UserDefaults`를 한 겹 감싼다. 실제 `UserDefaults`를 테스트가 직접 쓰면 상태가 새고
    실행 순서에 결과가 흔들린다 (`PhotoData.CameraOnboardingStorage`와 같은 판단)

### Sample (`Sources/Sample/`)

- `enum RoomSamples` — `inviteCode`(시안의 `1928121`) · `inviteCodes` ·
  `shootingOnly` · `completedOnly` · `mixed` (전부 `[RoomCard]`)
  - 목록 구성이 데모앱의 화면 상태와 1:1로 대응한다
  - `RoomCard.previewXxx`(Domain)와 용도가 다르다 — 그쪽은 `#Preview`용이라 네트워크 없이 즉시
    그려져야 해 사진이 비어 있고, 이쪽은 실행 중이라 사진을 받아올 수 있다. 사진이 없으면 인화 카드의
    낱장 스택과 "+N" 오버레이를 시안과 대조할 수 없다
  - 사진은 picsum 시드 URL이라 시드가 같으면 항상 같은 사진이 온다. 날짜도 고정값 —
    검수할 때마다 화면이 달라지지 않는다

## 내부 구성 (internal — 서버 계약이 바뀌면 여기만 바뀐다)

- `DTO/` — 스웨거 스키마와 1:1. `BaseResponseDTO`(공통 껍데기 `{success, message, data}`,
  UserData 복사본 — CHALLANetwork 공통화는 #51 진행 중), 요청·응답 DTO, `RoomStatusDTO`
  (모르는 상태 값은 디코딩 실패를 택한다). 날짜는 `String`으로 받는다 — 공용 디코더에 날짜 규칙을
  설정하면 다른 도메인 API까지 영향을 받아 매핑에서만 파싱한다
- `Endpoint/RoomEndpoint` — rooms(배열 쿼리) · shootable · create · join · detail · members ·
  checkPrintCompletion(PUT) · updateTitle(PUT) 선언. 전부 `.bearer`
- `Mapping/` — `toDomain()`(DTO→RoomCard·RoomDetail·ShootableRoom), `ServerDate`(소수점 초 자릿수만 다른 3형식
  파싱 — 마이크로초 6·밀리초 3·생략. 타임존 표기 없이 UTC로 내려온다, 백엔드 확정 2026-08-13),
  `RoomError.normalized`(취소는 통과,
  401→unauthorized, 404→roomNotFound·409→roomFull은 잠정 — 스웨거에 에러 정의가 없음 TODO)
  - 필수 날짜(createdAt·expiresAt) 파싱 실패는 그 방을 오류 처리, 인화 완료 시각·확인 시각은
    null이 정상인 값이라(인화 전·확인 전) 형식이 깨져도 그 값만 nil

## 의존성

- **이 모듈이 의존**: `RoomDomain`(인터페이스·엔티티·오류) · `CHALLANetwork`(HTTPClient·Endpoint)
- **이 모듈에 의존**: `CHALLAApp` · `HomeFeatureDemo` · `RoomDetailFeatureDemo` · `CameraFeatureDemo` — 합성 루트만 import한다
  (아키텍처 규칙 2: Feature는 Data를 import하지 않는다)

## 테스트 실행 방법

```bash
mise exec -- tuist test RoomData
```

Swift Testing 기반 순수 유닛테스트(시뮬레이터 불필요). `Tests/Support/MockHTTPClient`
(호출 캡처 + 준비된 JSON 응답, UserData 것에 `queryItems` 캡처 추가한 복사본)로 서버 없이 검증한다.

- `DefaultRoomRepositoryTests` — 상태 3개 배열 쿼리·bearer 확인, `success:false` 언랩(서버 메시지
  보존), transport→`.network` 정규화, 생성·입장의 본문 계약과 재조회 왕복(POST→GET 순서),
  재조회 실패 시 `.unknown`, 404·409 잠정 매핑, 상세·참여자의 경로·응답 매핑과 404→`.roomNotFound`
- `RoomCardMappingTests` — 필드 이동·`shotPhotoCount` 계산, 상태 3종 1:1, 날짜 3형식 파싱,
  필수 날짜 위반 시 `.unknown`, 인화 시각 관대 처리, 깨진 썸네일 URL 걸러내기
- `RoomDetailMappingTests` — 상세 응답 필드 이동 / 필수 날짜 정책 동일 /
  참여자 매핑(닉네임 nil 통과·깨진 URL 버림)
- `ShootableRoomsTests` — 촬영 가능 목록 경로·bearer 확인, `success:false` 언랩,
  InMemory의 촬영 중 상태 필터링
- `InMemoryRoomRepositoryTests` — 시작 목록 순서 유지, 생성 시 서버 몫 값을 저장소가 채우는지
  (id 음수 표식 포함), 만든 방이 목록에 남고 최근 방이 맨 앞, 입장 인원 증가 반영,
  없는 코드의 `.roomNotFound`, 상세의 초대 코드 두 경로(역방향 조회·id로 생성),
  참여자 주입 반환, `failure` 주입 시 모든 메서드 전파
- `DefaultPrintNoticeRepositoryTests` — 기록 없을 때 기본값, 기록 후 유지, 방별 분리,
  저장소를 물려받은 새 인스턴스가 기록을 읽는지 (앱 재실행 상황)

`RoomSamples`는 값 선언뿐이라 테스트하지 않는다.
