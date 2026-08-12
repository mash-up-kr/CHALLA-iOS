# RoomDomain

## 레이어와 책임

**Domain 레이어**. 방(Room)에 관한 순수 도메인 모듈이다 — 엔티티, 입력 규칙, 저장소 인터페이스,
Feature-facing UseCase를 정의한다. 서버·저장소의 존재를 모르며(import는 `Foundation` +
`Dependencies`/`DependenciesMacros`뿐), 인터페이스 구현은 `RoomData`가 맡는다
(아키텍처 규칙 1: `Feature → Domain ← Data`).

**화면이 아니라 대상 단위로 한 벌이다.** 홈·방 상세·촬영 등 방을 다루는 모든 Feature가 이 모듈 하나를
공유한다. 화면마다 Domain을 만들면 같은 `Room` 엔티티가 여러 벌 생긴다.

**엔티티는 서버 두 API의 교집합이다 (#54).** 목록(`GET /rooms`)과 상세(`GET /rooms/{id}`)가
공통으로 주는 필드만 `Room`에 담고, 한쪽 API만 주는 값은 화면별 Model(`RoomCard`, 추후 `RoomDetail`)이
`Room`을 감싸며 들고 있다. 어느 값이 어느 API에서 오는지 타입에 드러나고, 홈→상세로 `Room`을 넘겨
첫 프레임부터 그릴 수 있다.

**의존 주입 설계**: UseCase는 `@DependencyClient` + `TestDependencyKey`로 선언하고 **`liveValue`를
의도적으로 두지 않는다**. 인자 없는 `liveValue`를 채우려면 구체 저장소를 생성해야 하고, 그러려면 Data를
import해야 해 규칙 2가 깨진다. 대신 `.live(repository:)` 팩토리가 인터페이스만 받아 규칙을 조립하고,
구체 저장소를 넘기는 일은 합성 루트(`CHALLAApp`·`HomeFeatureDemo`의 `CompositionRoot`)가 한다.
`AuthDomain`과 같은 구조다.

**동시성**: 모든 공개 타입이 값 타입 + `Sendable`이다 (`@unchecked` 미사용).

## 공개 API

폴더는 한 종류만 담는다 — `Entities/`는 엔티티, `Errors/`는 실패 목록, `Interface/`는 protocol,
`Models/`는 파생 구조, `Rules/`는 입력 규칙, `UseCases/`는 유스케이스.

### Entities (`Sources/Entities/`)

- `struct Room` — 방 그 자체 (목록·상세 API의 교집합 8필드). `id: Int64`(서버 발급) · `title` ·
  `status` · `totalPhotoCount: Int` · `remainedPhotoCount` · `createdAt` · `expiresAt` ·
  `photoPrintCompletedAt?`(인화 전에는 nil이 정상). 전 필드 `let`이라 갱신은 새 값을 만든다
  - `shotPhotoCount` — 찍은 장수 계산 프로퍼티 (`total − remained`, 서버는 남은 장수를 준다)
  - `enum Room.Status` — `.shooting` / `.printWaiting` / `.printed`
  - `Room.previewShooting` · `previewPrintWaiting` · `previewPrinted` · `previewRooms` —
    `#Preview`·테스트용 상수. id는 음수(-1~-3, 서버 양수 id와 불겹침 표식), 날짜는 고정값
- `enum RoomShotCount: Int` — `.twentyFour`(24) / `.fortyEight`(48) / `.seventyTwo`(72), `.default`는 24
  - **방을 만들 때 고르는 입력값의 규칙**이라 `RoomDraft` 전용이다. 이미 존재하는 방의
    `totalPhotoCount`는 서버가 정하는 자유값이라 enum이 아니다

### Errors (`Sources/Errors/`)

- `enum RoomError` — `.network` · `.unauthorized` · `.invalidRoomName` · `.invalidInviteCode` ·
  `.roomNotFound` · `.roomFull` · `.server(message:)` · `.unknown`
  - `userMessage` — 얼럿 문구. 기획 가이드 확정 전까지는 임의 작성본이다

### Interface (`Sources/Interface/` — 구현: RoomData)

- `protocol RoomRepository` — `rooms() -> [RoomCard]` · `createRoom(_:) -> RoomCard` ·
  `joinRoom(inviteCode:) -> RoomCard`
  - 구현체 계약: 실패는 반드시 `RoomError`로 번역해 던진다. 입력값 검증은 UseCase가 이미 마쳤다
  - 생성·입장도 카드를 돌려준다 — 홈이 성공 직후 목록에 꽂을 수 있어야 하고, 서버 응답이
    부실해도(id만 주는 등) 그 사정은 구현체가 흡수한다

### Models (`Sources/Models/`)

경계 하나만을 위한 입출력 구조와 엔티티에서 파생된 결과. 정체성도 수명도 없어 `Entities/`와 섞지 않는다.

- `struct RoomCard` — 홈 목록 한 칸 (`GET /rooms` 응답 한 줄에 대응). `room: Room` +
  목록 API만 주는 값(`memberCount` · `thumbnailURLs`)
  - `id`는 `room.id`를 그대로 노출 — 카드 탭이 방 식별로 바로 이어진다
  - `coverImageURL` — 촬영 중 카드의 대표 사진 = 첫 썸네일 (서버에 별도 필드 없음, 백엔드 확인 TODO)
  - `previewShooting` · `previewPrintWaiting` · `previewPrinted` · `previewCards` 상수
- `struct RoomDraft` — `name` · `shotCount`. 방을 만들기 전의 입력값이라 `Room`으로 표현할 수 없다
  (id·상태·인원수는 서버가 채운다)
- `struct RoomBoard` — 카드 배열 하나를 `shooting` / `completed` 두 배열로 가른 결과. `isEmpty`
  - 섹션별로 따로 조회하지 않기 위한 타입이다. 두 번 조회하면 그 사이에 상태가 바뀐 방이
    양쪽에 나오거나 어디에도 안 나온다
- `enum RoomSection` — `.shooting` / `.completed`
- `Room.Status.section` — 상태 셋을 섹션 둘로 줄인다

### Rules (`Sources/Rules/`)

UseCase가 `async`라 타이핑마다 부를 수 없어 규칙만 따로 뗀 것이다. 버튼 활성 판단은 뷰가 동기로 한다.

- `enum RoomNameRule` — `maxLength`(20) · `truncated(_:)` · `trimmed(_:)` · `isSubmittable(_:)`
  - `truncated`는 타이핑 중에, `trimmed`는 제출 시점에 쓴다. 타이핑 중 공백을 떼면 단어 사이를 띄울 수 없다
- `enum InviteCodeRule` — `trimmed(_:)` · `isSubmittable(_:)`
  - 지금 거르는 것은 빈 값 하나뿐이다. 자릿수·문자셋은 형식이 정해지면 추가한다

### UseCases (`@DependencyClient` — `liveValue` 없음)

- `FetchRoomsUseCase` (`\.fetchRoomsUseCase`) — 방 카드 목록 조회 (`-> [RoomCard]`)
- `CreateRoomUseCase` (`\.createRoomUseCase`) — `RoomNameRule` 적용 후 생성 (`-> RoomCard`).
  규칙 위반이면 저장소를 부르지 않고 `.invalidRoomName`
- `JoinRoomUseCase` (`\.joinRoomUseCase`) — `InviteCodeRule` 적용 후 입장 (`-> RoomCard`).
  빈 코드면 `.invalidInviteCode`

셋 다 `static func live(repository:)` · `testValue` · `previewValue`를 갖는다.

## 의존성

- **이 모듈이 의존**: `Dependencies` · `DependenciesMacros` (TCA 전이 의존, `Tuist/Package.swift` 경유)
- **이 모듈에 의존**: `HomeFeature`(UseCase를 `@Dependency`로 주입받음) ·
  `RoomData`(인터페이스 구현) · 합성 루트(`CHALLAApp`·`HomeFeatureDemo` — `.live(repository:)` 조립)

## 테스트 실행 방법

```bash
mise exec -- tuist test RoomDomain
```

Swift Testing 기반 순수 유닛테스트(시뮬레이터 불필요). `Tests/Support/MockRoomRepository`로
인터페이스만 갈아끼워 검증한다.

- `RoomNameRuleTests` — 20자 경계, 한글·조합 이모지 한 글자 계산, `normalize`가 앞뒤만 떼는지,
  공백만 입력한 이름
- `InviteCodeRuleTests` — 앞뒤 공백 제거, 공백만 입력한 코드
- `RoomBoardTests` — 상태 셋 → 섹션 둘 분류, 섹션 안 순서 유지, 빈 판단
- `RoomErrorTests` — `userMessage` 각 케이스, 빈 서버 메시지의 기본 문구 대체, 연관값까지 보는 동등성
- `FetchRoomsUseCaseLiveTests` — 저장소 결과 그대로 전달, 오류 전파
- `CreateRoomUseCaseLiveTests` — 이름 정규화·자르기 순서, 규칙 위반 시 저장소 미호출, 오류 전파
- `JoinRoomUseCaseLiveTests` — 코드 정규화 후 전달, 빈 코드 가드, `.roomNotFound` 전파
