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
  `photoPrintCompletedAt?`(인화 완료 예정 시각 = 촬영 완료 +24h — 촬영 중에만 nil, 카운트다운 기준값). 전 필드 `let`이라 갱신은 새 값을 만든다
  - `shotPhotoCount` — 찍은 장수 계산 프로퍼티 (`total − remained`, 서버는 남은 장수를 준다)
  - `renamed(to:)` — 제목만 바꾼 사본. 이름 변경이 서버에 저장된 직후, 재조회가 오기 전
    구간에 화면이 새 제목을 먼저 그리는 용도 (App의 화면 조립·InMemory 저장소가 쓴다)
  - `enum Room.Status` — `.shooting` / `.printWaiting` / `.printed`
  - `Room.previewShooting` · `previewPrintWaiting` · `previewPrinted` · `previewRooms` —
    `#Preview`·테스트용 상수. id는 음수(-1~-3, 서버 양수 id와 불겹침 표식), 날짜는 고정값
  - `Room.previewLifetime`(30일) · `previewPrintCompletionOffset`(3일) — 프리뷰·샘플·가짜 저장소가
    함께 쓰는 날짜 간격. 실제 만료는 서버가 `expiresAt`으로 내려주므로 화면 로직에서 쓰지 않는다
- `struct RoomMember` — 방에 참여한 사람 (`GET /rooms/{id}/users`의 한 줄). `id: Int64`(서버 발급) ·
  `nickname?` · `imageURL?`(프로필 미설정 사용자는 nil). 사진 작성자·채팅 발신자와 같은 사람을
  가리키는 정체성이라 엔티티다
- `enum RoomShotCount: Int` — `.twentyFour`(24) / `.fortyEight`(48) / `.seventyTwo`(72), `.default`는 24
  - **방을 만들 때 고르는 입력값의 규칙**이라 `RoomDraft` 전용이다. 이미 존재하는 방의
    `totalPhotoCount`는 서버가 정하는 자유값이라 enum이 아니다

### Errors (`Sources/Errors/`)

- `enum RoomError` — `.network` · `.unauthorized` · `.invalidRoomName` · `.invalidInviteCode` ·
  `.roomNotFound` · `.roomFull` · `.server(message:)` · `.unknown`
  - `userMessage` — 얼럿 문구. 기획 가이드 확정 전까지는 임의 작성본이다

### Interface (`Sources/Interface/` — 구현: RoomData)

- `protocol RoomRepository` — `rooms() -> [RoomCard]` · `shootableRooms() -> [ShootableRoom]` ·
  `createRoom(_:) -> RoomCard` · `joinRoom(inviteCode:) -> RoomCard` ·
  `roomInfo(id:) -> (room, invitationCode)` · `members(roomID:) -> [RoomMember]` ·
  `checkPrintCompletion(roomID:)` · `updateTitle(roomID:title:)`
  - 구현체 계약: 실패는 반드시 `RoomError`로 번역해 던진다. 입력값 검증은 UseCase가 이미 마쳤다
  - 생성·입장도 카드를 돌려준다 — 홈이 성공 직후 목록에 꽂을 수 있어야 하고, 서버 응답이
    부실해도(id만 주는 등) 그 사정은 구현체가 흡수한다
  - 상세는 API 하나당 메서드 하나로 나뉜다 — 상세 API 하나로는 `RoomDetail`을 완성할 수 없어
    (참여자 없음) 반쪽짜리를 돌려주지 않기 위한 분리. 합치기는 UseCase 몫
  - 확인 기록·이름 변경은 반환이 없다 — 반영된 값은 다음 목록 조회가 내려준다
- `protocol InviteGuideRepository` — `hasSeenInviteGuide()` · `markInviteGuideSeen()`.
  방 상세 첫 진입 안내를 봤는지의 기록. 기기에만 남고 서버에 올리지 않는다 —
  기기를 바꾸면 안내가 한 번 더 뜬다

### Models (`Sources/Models/`)

경계 하나만을 위한 입출력 구조와 엔티티에서 파생된 결과. 정체성도 수명도 없어 `Entities/`와 섞지 않는다.

- `struct RoomCard` — 홈 목록 한 칸 (`GET /rooms` 응답 한 줄에 대응). `room: Room` +
  목록 API만 주는 값(`memberCount` · `thumbnailURLs` · `photoPrintCompletionCheckedAt?`)
  - `isPrintCompletionChecked` — 확인 여부 (`photoPrintCompletionCheckedAt != nil`).
    홈이 인화 완료 방을 상단(미확인)·하단(확인)으로 가르는 기준값
  - `id`는 `room.id`를 그대로 노출 — 카드 탭이 방 식별로 바로 이어진다
  - `coverImageURL` — 촬영 중 카드의 대표 사진 = 첫 썸네일 (서버에 별도 필드 없음, 백엔드 확인 TODO)
  - `previewShooting` · `previewPrintWaiting` · `previewPrinted` · `previewCards` 상수
- `struct RoomDetail` — 방 상세 화면 하나를 위한 Model. `room: Room` + 상세 API만 주는 값
  (`invitationCode` · `members`). `RoomCard`와 같은 구조로 `Room` 코어를 감싼다. `preview` 상수 포함
- `struct RoomDraft` — `name` · `shotCount`. 방을 만들기 전의 입력값이라 `Room`으로 표현할 수 없다
  (id·상태·인원수는 서버가 채운다)
- `struct RoomBoard` — 카드 배열 하나를 `active`(촬영 중·인화 대기·미확인 인화 완료) /
  `printed`(확인을 마친 인화 완료) 두 배열로 가른 결과. `isEmpty`
  - 인화 완료 방은 확인 여부에 따라 한쪽에만 놓인다 — 겹치지 않는다
  - 순서는 두 목록 모두 입력 배열 그대로 — 정렬(완료 → 촬영 가능 → 대기 남은 시간 짧은 순)은
    서버가 구현하기로 합의했다 (2026-08-23 백엔드 합의)
  - 섹션별로 따로 조회하지 않기 위한 타입이다. 두 번 조회하면 그 사이에 상태가 바뀐 방이
    양쪽에 나오거나 어디에도 안 나온다
- `struct ShootableRoom` — 카메라의 방 선택 목록 한 줄 (`GET /rooms/shootable` 응답 한 줄에 대응).
  `id: Room.ID` · `title` · `remainedPhotoCount` · `totalPhotoCount`
  - 촬영 화면은 제목·남은 장수만 필요해 `Room` 전체가 아니라 이 축약형을 쓴다
  - `previewRooms` 상수 (id 음수 규칙은 `Room` 샘플과 같다)

### Rules (`Sources/Rules/`)

UseCase가 `async`라 타이핑마다 부를 수 없어 규칙만 따로 뗀 것이다. 버튼 활성 판단은 뷰가 동기로 한다.

- `enum RoomNameRule` — `maxLength`(20) · `truncated(_:)` · `trimmed(_:)` · `isSubmittable(_:)`
  - `truncated`는 타이핑 중에, `trimmed`는 제출 시점에 쓴다. 타이핑 중 공백을 떼면 단어 사이를 띄울 수 없다
- `enum InviteCodeRule` — `trimmed(_:)` · `isSubmittable(_:)`
  - 지금 거르는 것은 빈 값 하나뿐이다. 자릿수·문자셋은 형식이 정해지면 추가한다
- `enum PrintCountdown` — `text(until:now:)`. "2:59:58" 표기 — 시는 자릿수 제한 없이,
  분·초는 두 자리, 0 아래로 내려가지 않는다. 홈 카드의 대기 뱃지와 방 상세 카운트다운 바가
  같은 표기를 쓴다
- `enum InviteLink` — 초대 링크 주소 형식(`https://challa.stellaris.co.kr/invite/{코드}`)을
  아는 유일한 곳. 보낼 때는 `url(code:)`(방 상세 공유 시트), 받을 때는 `code(from:)`
  (유니버설 링크 진입 — CHALLAApp). 파싱은 우리 도메인의 그 모양일 때만 코드를 돌려준다

### UseCases (`@DependencyClient` — `liveValue` 없음)

- `FetchRoomsUseCase` (`\.fetchRoomsUseCase`) — 방 카드 목록 조회 (`-> [RoomCard]`)
- `FetchShootableRoomsUseCase` (`\.fetchShootableRoomsUseCase`) — 촬영 가능한 방 목록 조회
  (`-> [ShootableRoom]`, 카메라의 방 선택 드로어용)
- `CreateRoomUseCase` (`\.createRoomUseCase`) — `RoomNameRule` 적용 후 생성 (`-> RoomCard`).
  규칙 위반이면 저장소를 부르지 않고 `.invalidRoomName`
- `JoinRoomUseCase` (`\.joinRoomUseCase`) — `InviteCodeRule` 적용 후 입장 (`-> RoomCard`).
  빈 코드면 `.invalidInviteCode`
- `FetchRoomDetailUseCase` (`\.fetchRoomDetailUseCase`) — 상세·참여자 두 API를 `async let`
  병렬 조회해 `RoomDetail` 하나로 (`-> RoomDetail`). 한쪽이 실패하면 다른 쪽은 취소되고
  오류 하나만 전파된다
- `CheckPrintCompletionUseCase` (`\.checkPrintCompletionUseCase`) — 인화 완료 확인을 서버에 기록
  (`(roomID) -> Void`). 규칙 없는 단순 통과지만 Feature는 UseCase만 보는 관례를 유지한다
- `UpdateRoomTitleUseCase` (`\.updateRoomTitleUseCase`) — `RoomNameRule` 적용 후 이름 변경
  (`(roomID, title) -> String`). 정제된 이름을 돌려줘 화면이 입력값 대신 서버 저장값으로 갱신한다
- `ShouldShowInviteGuideUseCase` (`\.shouldShowInviteGuideUseCase`) — 방 상세에 처음
  들어왔는지 (`-> Bool`, 던지지 않음). previewValue는 false — 프리뷰마다 안내가 겹치지 않게,
  안내 컷은 직접 true를 꽂는다
- `MarkInviteGuideSeenUseCase` (`\.markInviteGuideSeenUseCase`) — 안내를 본 것으로 기록 (`-> Void`)

전부 `static func live(repository:)` · `testValue` · `previewValue`를 갖는다.

## 의존성

- **이 모듈이 의존**: `Dependencies` · `DependenciesMacros` (TCA 전이 의존, `Tuist/Package.swift` 경유)
- **이 모듈에 의존**: `HomeFeature`·`CameraFeature`(UseCase를 `@Dependency`로 주입받음) ·
  `RoomData`(인터페이스 구현) · 합성 루트(`CHALLAApp`·`HomeFeatureDemo`·`CameraFeatureDemo` —
  `.live(repository:)` 조립)

## 테스트 실행 방법

```bash
mise exec -- tuist test RoomDomain
```

Swift Testing 기반 순수 유닛테스트(시뮬레이터 불필요). `Tests/Support/MockRoomRepository`로
인터페이스만 갈아끼워 검증한다.

- `RoomNameRuleTests` — 20자 경계, 한글·조합 이모지 한 글자 계산, `normalize`가 앞뒤만 떼는지,
  공백만 입력한 이름
- `InviteCodeRuleTests` — 앞뒤 공백 제거, 공백만 입력한 코드
- `RoomBoardTests` — 확인 여부 기준 상단·하단 분류(겹침 없음), 입력 순서 유지, 빈 판단
- `PrintCountdownTests` — 시 자릿수 무제한, 분·초 두 자리 패딩, 완료 시각 경과 시 0:00:00 고정
- `RoomErrorTests` — `userMessage` 각 케이스, 빈 서버 메시지의 기본 문구 대체, 연관값까지 보는 동등성
- `FetchRoomsUseCaseLiveTests` — 저장소 결과 그대로 전달, 오류 전파
- `FetchShootableRoomsUseCaseLiveTests` — 저장소 결과 그대로 전달, 오류 전파
- `CreateRoomUseCaseLiveTests` — 이름 정규화·자르기 순서, 규칙 위반 시 저장소 미호출, 오류 전파
- `JoinRoomUseCaseLiveTests` — 코드 정규화 후 전달, 빈 코드 가드, `.roomNotFound` 전파
- `FetchRoomDetailUseCaseLiveTests` — 두 결과의 합치기(같은 id로 호출됐는지 캡처 검증),
  어느 쪽이 실패해도 부분 성공 없이 오류 하나 전파
- `InviteGuideUseCasesLiveTests` — 기록이 없을 때만 띄우라고 답하는지, 기록이 이후 조회에 반영되는지
- `InviteLinkTests` — 링크 모양·라운드트립, 우리 링크가 아닌 URL 5종 거부, 끝 슬래시 허용
