# PhotoDomain

## 레이어와 책임

**Domain 레이어**. 사진 aggregate 한 벌 — 방에서 찍힌 사진(조회·리액션·저장)과
사진 촬영(카메라 필터·업로드·권한·안내)의 규칙을 함께 담는다. 서버·사진첩·SwiftUI를 모르며
(import는 `Foundation` + `Dependencies`/`DependenciesMacros`뿐), 인터페이스 구현은
`PhotoData`·Core가 맡는다 (아키텍처 규칙 1: `Feature → Domain ← Data`).

**화면이 아니라 대상 단위로 한 벌이다.** 카메라·사진 상세 등 사진을 다루는 Feature가 이 모듈을
공유한다 (`RoomDomain`과 같은 원칙 — `docs/ARCHITECTURE.md`의 "Camera는 Room·Photo·Core 재사용").
인화 전 필름은 여기 없다 — 인화 상태는 방의 상태라 `RoomDomain` 소관이고,
이 모듈은 촬영과 인화가 끝나 볼 수 있게 된 사진을 다룬다.

**의존 주입 설계**: UseCase는 `@DependencyClient` + `TestDependencyKey`로 선언하고 `liveValue`를
의도적으로 두지 않는다 — 인자 없는 `liveValue`를 만들려면 Domain이 Data를 import해야 해서
규칙 2가 깨진다. 조립은 합성 루트가 `.live(repository:)`/`.live(uploader:)`로 한다.
주입하지 않고 쓰면 런타임에 "no live implementation"이 뜨는데, 이는 의도된 설계다.

## 공개 API

### Entities (`Sources/Entities/`)

| 타입 | 내용 |
| :-- | :-- |
| `Photo` | 사진 정보, 리액션 스티커, 사용자별 선택 종류. `addingReaction(_:)`, `removingReaction(id:)`으로 갱신하고 `applyingReactions(_:)`으로 서버 조회를 반영한다. 조회 시 채팅 ID로 기존 표시 ID를 유지하며, 아직 채팅 ID가 없는 스티커는 사용자·종류로 연결한다 |
| `PhotoAuthor` | `id` · `nickname` · `avatarURL` — 사진에 박제된 시점의 촬영자 정보 |
| `ReactionKind` | 리액션 10종(heart · sparkle · thumbsUp · poop · skull · medal · question · huh · loveEyes · fire). 시안의 리액션 바 순서 그대로이며 이모지 글리프는 화면이 정한다 |
| `PhotoReaction` | `id`(표시용) · `kind` · `userID` · `chatID`(삭제용, nullable). `attachingChatID(_:)`는 표시 ID를 유지한다. 스티커 좌표는 Feature가 계산한다 |
| `PhotoReactions` | 사진 한 장의 리액션 묶음 — `stickers`(남긴 순서대로 전부) + `reactedKindsByUser`(유저별 종류 전부, 칩 띠용). 목록엔 리액션이 없어 펼칠 때 따로 받아 `Photo.applyingReactions(_:)`로 채운다 |
| `CameraFilter` | 서버가 내려주는 카메라 필터 한 개 (`GET /shoots/camera-filters` 응답 한 줄). `name`(식별자 겸 표시 이름 — 사진 업로드 API도 이 값으로 필터를 가리킨다) · `fileURL`(LUT .cube 공개 URL). `previewFilters`는 화면 확인용 샘플 |

### Errors (`Sources/Errors/`)

- `enum PhotoError` — `.network` · `.unauthorized` · `.photoExhausted`(방의 남은 장수 소진) ·
  `.permissionDenied` · `.saveFailed` · `.server(message:)` · `.unknown`
  - `userMessage` — 토스트·얼럿 문구. 기획 가이드 확정 전까지는 임의 작성본이다

### Interface (`Sources/Interface/` — 구현: PhotoData · Core)

- `protocol PhotoRepository` — `photos(inRoom:)`(목록만) · `reactions(inRoom:photoID:)`(사진 한 장의 리액션 → `PhotoReactions`) · `setReaction(roomID:photoID:kind:)` · `deleteReaction(chatID:)` · `imageData(for:)` · `imageDataStream(for:)`.
  리액션 생성은 채팅 ID를 반환한다. 성공 응답에 ID가 없을 수 있으므로 반환형은 `Int64?`이다.
  삭제는 `deleteReaction(chatID:)`로 요청한다.
  `imageDataStream(for:)`은 여러 장의 원본을 넘긴 순서대로 흘려 준다(전체 다운로드용)
- `protocol PhotoLibraryWriting` — `save(imageData:)`. 권한 요청까지 구현체 안에서 끝낸다
- `protocol CameraFilterRepository` — `filters() -> [CameraFilter]` · `lutData(for:) -> Data`
  - LUT 파싱·CoreImage 변환은 호출부(화면 조립) 몫 — Domain·Data는 색 변환 기술을 모른다.
    `PrepareCameraFiltersUseCase`가 그 호출부의 `register`를 받아 다운로드와 이어 붙인다
- `protocol PhotoUploader` — `upload(jpegData:roomID:filterName:) -> Int`(그 방의 남은 장수)
  - 서명 URL 발급 → 스토리지 PUT → 완료 통보의 다단계 절차를 한 호출로 감춘다
    (`ProfileImageUploader`와 같은 구조)
- `protocol CameraOnboardingRepository` — `hasSeenCoachMark() -> Bool` · `markCoachMarkSeen()`
  - 카메라 진입 안내를 이미 봤는지 기억한다. 기기에만 남기고 서버에 올리지 않는다
- `protocol CameraPermissionProvider` — `requestAccess() -> Bool` · `openSystemSettings()`
  - 촬영 진입 버튼이 목록 조회와 함께 권한을 받아 둔다. 이미 거절한 뒤에는 다시 물을 수 없어
    `false`가 오고, 호출부가 설정 앱으로 안내한다

구현체 공통 계약: 실패는 반드시 `PhotoError`로 정규화해 던진다.

### UseCases (`DependencyValues` 키 — `liveValue` 없음)

사진(조회·리액션·저장):

| 키 | live 팩토리 | 하는 일 |
| :-- | :-- | :-- |
| `\.fetchRoomPhotosUseCase` | `.live(repository:)` | 방의 사진을 찍힌 순서대로 가져온다(목록만 — 리액션 제외) |
| `\.fetchPhotoReactionsUseCase` | `.live(repository:)` | 사진 한 장의 리액션(`PhotoReactions`)을 가져온다. 사진을 펼칠 때만 호출해 1+N 회피 |
| `\.setPhotoReactionUseCase` | `.live(repository:)` | 사진에 리액션을 남기고 생성된 채팅 id를 돌려준다(화면은 호출부가 낙관적으로 갱신) |
| `\.deletePhotoReactionUseCase` | `.live(repository:)` | 리액션(EMOJI 채팅) 한 건을 채팅 id로 지운다 |
| `\.savePhotoUseCase` | `.live(repository:photoLibrary:)` | 원본을 내려받아 사진첩에 저장한다. 계약을 어긴 오류가 새어 나와도 `PhotoError.unknown`으로 막는다 |
| `\.saveAllPhotosUseCase` | `.live(repository:photoLibrary:)` | 여러 장을 사진첩에 저장하며 진행 상황을 `SaveAllPhotosEvent`로 흘린다. 받기는 병렬, 저장은 순차 |

촬영(필터·업로드·안내·권한):

- `FetchCameraFiltersUseCase` (`\.fetchCameraFiltersUseCase`) — 필터 목록 조회 (`-> [CameraFilter]`)
- `PrepareCameraFiltersUseCase` (`\.prepareCameraFiltersUseCase`) — 필터들의 LUT를 모두 내려받아 등록.
  하나라도 실패하면 던진다 — 진입 버튼이 이 결과로 카메라 진입 여부를 정한다.
  파싱·등록은 Domain이 모르는 색 변환 영역이라 `live(repository:register:)`로 주입받는다
- `UploadPhotoUseCase` (`\.uploadPhotoUseCase`) — 사진 업로드 후 남은 장수 (`-> Int`)
- `ShouldShowCameraCoachMarkUseCase` (`\.shouldShowCameraCoachMarkUseCase`) — 카메라 최초 진입인지 (`-> Bool`)
- `MarkCameraCoachMarkSeenUseCase` (`\.markCameraCoachMarkSeenUseCase`) — 안내를 끝까지 본 것으로 기록
- `RequestCameraPermissionUseCase` (`\.requestCameraPermissionUseCase`) — 카메라 접근 허용 여부 (`-> Bool`)
- `OpenCameraSettingsUseCase` (`\.openCameraSettingsUseCase`) — 설정 앱의 이 앱 화면 열기

전부 `static func live(...)` · `testValue` · `previewValue`를 갖는다.
안내·권한 관련 넷은 기기 저장값과 OS 권한만 다뤄 실패 개념이 없다 — 던지지 않는다.

### 이 모듈에 두지 않은 것

**스티커 배치** — 사진 위 어디에 붙는지는 `PhotoDetailFeature.StickerLayout`이 정한다.
격자·비워 두는 구간·기울기가 전부 시안 레이아웃에서 나온 값이고(사진 358 × 477, 스티커 82,
촬영자 표시 32 + 48), 서버는 좌표를 주지 않는다. 도메인이 "사진 카드 위쪽에 촬영자 이름이 얹힌다"를
알 이유가 없어 화면 쪽에 뒀다. 서버가 좌표를 주기 시작하면 그때 `PhotoReaction`에 실어 도메인으로 들인다.

**표시 문구** — `PhotoError.userMessage`만 예외로 여기 있다. 얼럿 제목은 화면이 정하고 본문만
오류가 들고 있는 형태인데, `AuthError.userMessage`가 같은 방식이라 선례를 따랐다.
문구 정책이 정해지면 두 모듈을 함께 옮기는 게 맞다.

## 의존성

- **이 모듈이 의존**: `Dependencies` · `DependenciesMacros` (TCA 전이 의존 — `@DependencyClient` 키 선언)
- **이 모듈에 의존**: `PhotoDetailFeature` · `CameraFeature` · `PhotoData`(인터페이스 구현) ·
  합성 루트(`CHALLAApp` · `PhotoDetailFeatureDemo` · `CameraFeatureDemo`)

## 테스트 실행 방법

```bash
mise exec -- tuist test PhotoDomain
```

Swift Testing 기반 순수 유닛테스트(시뮬레이터 불필요). `Tests/Support`의 목으로
인터페이스만 갈아끼워 검증한다.

- `PhotoReactionTests` — 켜기·끄기, 멱등성, 없는 것 끄기, 남의 리액션 보존, 종류별 누적, 중복 제거, 신원 규칙
- `PhotoUseCaseTests` — 방 ID 전달, 조회 실패 전파, 리액션 목표 상태 전달
- `SavePhotoUseCaseTests` — 바이트 전달, 내려받기 실패·권한 거부 전파, 취소 통과, 계약 밖 오류의 `unknown` 정규화
- `PhotoUseCasesLiveTests` — 촬영 쪽 UseCase들의 결과 전달·인자 전달·오류 전파, 안내 노출 판단·기록

스티커 배치 테스트는 `PhotoDetailFeature`로 옮겼다 — 규칙이 그쪽에 있다.
