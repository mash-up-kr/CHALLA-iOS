# PhotoDomain

## 레이어와 책임

**Domain 레이어**. 방에서 다루는 사진의 순수 규칙을 담는다 — 두 축이다: (1) 찍힌 사진(Photo)과 리액션,
사진첩 저장, (2) 서버가 내려주는 카메라 필터와 사진 업로드. 엔티티·저장소 인터페이스·유스케이스·도메인
오류가 전부이며 서버·스토리지·사진첩·SwiftUI를 모른다 (import는 `Foundation` + `Dependencies`/`DependenciesMacros`뿐).
인터페이스 구현은 `PhotoData`·Core가 맡는다 (아키텍처 규칙 1: `Feature → Domain ← Data`).

**화면이 아니라 대상(aggregate) 단위로 한 벌이다.** 카메라·사진 상세 등 사진을 다루는 Feature가 이 모듈을
공유한다 (`RoomDomain`과 같은 원칙 — `docs/ARCHITECTURE.md`의 "Camera는 Room·Photo·Core 재사용").
인화 전 필름은 여기 없다 — 인화 상태는 방의 상태라 `RoomDomain` 소관이고, 이 모듈은 인화가 끝나 볼 수
있게 된 사진만 다룬다.

**의존 주입 설계**: UseCase는 `@DependencyClient` + `TestDependencyKey`로 선언하고 `liveValue`를
의도적으로 두지 않는다 — 조립은 합성 루트가 `static func live(...)` 팩토리에 구현체를 넘겨 한다
(`AuthDomain`·`RoomDomain`과 같은 구조). 인자 없는 `liveValue`를 만들려면 Domain이 Data를 import해야 해
규칙 2가 깨지기 때문이다. 주입하지 않고 쓰면 런타임에 "no live implementation"이 뜨는데, 이는 의도된 설계다.

## 공개 API

### Entities

| 타입 | 내용 |
| :-- | :-- |
| `Photo` | `id` · `imageURL` · `author` · `capturedAt` · `reactions`. `hasReaction(_:by:)`로 내 리액션 여부를 묻고, `settingReaction(_:by:isOn:)`으로 리액션을 목표 상태에 맞춘 사본을 만든다(낙관적 갱신용). `init`에서 같은 신원의 리액션 중복을 걷어낸다 |
| `PhotoAuthor` | `id` · `nickname` · `avatarURL` — 사진에 박제된 시점의 촬영자 정보 |
| `ReactionKind` | 리액션 종류. 시안 순서 그대로이며 이모지 글리프는 화면이 정한다 |
| `PhotoReaction` | `kind` · `userID` — 한 사람이 한 사진에 남긴 리액션 하나. `종류 + 사람`이 곧 `id`다. 스티커 좌표는 갖지 않는다 |
| `CameraFilter` | 서버가 내려주는 카메라 필터 한 개 (`GET /shoots/camera-filters` 응답 한 줄). `name`(식별자 겸 표시 이름 — 사진 업로드 API도 이 값으로 필터를 가리킨다) · `fileURL`(LUT .cube 공개 URL). `previewFilters`는 화면 확인용 샘플(URL은 자리표시자) |

### Interface (구현은 Data · Core가 맡는다)

- `PhotoRepository` — `photos(inRoom:)` · `setReaction(photoID:kind:isOn:)` · `imageData(for:)`.
  리액션은 뒤집기가 아니라 **목표 상태를 지시하는 멱등 형태**다 — 같은 요청이 두 번 나가도 결과가
  같아야 재시도·취소가 안전하고, 화면이 먼저 그린 상태와 요청이 어긋나지 않는다
- `PhotoLibraryWriting` — `save(imageData:)`. 권한 요청까지 구현체 안에서 끝낸다
- `CameraFilterRepository` — `filters() -> [CameraFilter]` · `lutData(for:) -> Data`.
  LUT 파싱·CoreImage 변환은 호출부(화면 조립) 몫 — Domain·Data는 색 변환 기술을 모른다
- `PhotoUploader` — `upload(jpegData:roomID:filterName:) -> Int`(그 방의 남은 장수).
  서명 URL 발급 → 스토리지 PUT → 완료 통보의 다단계 절차를 한 호출로 감춘다 (`ProfileImageUploader`와 같은 구조)
- `CameraOnboardingRepository` — `hasSeenCoachMark() -> Bool` · `markCoachMarkSeen()`. 기기에만 남기고 서버에 올리지 않는다
- `CameraPermissionProvider` — `requestAccess() -> Bool` · `openSystemSettings()`. 이미 거절한 뒤에는 다시 물을 수 없어 `false`가 오고, 호출부가 설정 앱으로 안내한다

모든 인터페이스의 공통 계약: 실패는 전부 `PhotoError`로 정규화해 던진다.

### UseCases (`DependencyValues` 키 · `@DependencyClient` · `liveValue` 없음)

| 키 | live 팩토리 | 하는 일 |
| :-- | :-- | :-- |
| `\.fetchRoomPhotosUseCase` | `.live(repository:)` | 방의 사진을 찍힌 순서대로 가져온다 |
| `\.setPhotoReactionUseCase` | `.live(repository:)` | 리액션을 켜거나 끈 뒤 갱신된 사진을 돌려준다 |
| `\.savePhotoUseCase` | `.live(repository:photoLibrary:)` | 원본을 내려받아 사진첩에 저장한다. 계약을 어긴 오류가 새어 나와도 `PhotoError.unknown`으로 막는다 |
| `\.fetchCameraFiltersUseCase` | `.live(repository:)` | 카메라 필터 목록 조회 (`-> [CameraFilter]`) |
| `\.prepareCameraFiltersUseCase` | `.live(repository:register:)` | 필터들의 LUT를 모두 내려받아 등록. 하나라도 실패하면 던진다 — 진입 버튼이 이 결과로 카메라 진입 여부를 정한다 |
| `\.uploadPhotoUseCase` | `.live(uploader:)` | 사진 업로드 후 남은 장수 (`-> Int`) |
| `\.shouldShowCameraCoachMarkUseCase` | `.live(repository:)` | 카메라 최초 진입인지 (`-> Bool`) |
| `\.markCameraCoachMarkSeenUseCase` | `.live(repository:)` | 안내를 끝까지 본 것으로 기록 |
| `\.requestCameraPermissionUseCase` | `.live(provider:)` | 카메라 접근 허용 여부 (`-> Bool`) |
| `\.openCameraSettingsUseCase` | `.live(provider:)` | 설정 앱의 이 앱 화면 열기 |

안내·권한 관련 넷은 기기 저장값과 OS 권한만 다뤄 실패 개념이 없다 — 던지지 않는다.

### Errors

- `PhotoError` — `network` · `unauthorized` · `photoExhausted`(방의 남은 장수 소진) · `server(message:)` ·
  `permissionDenied` · `saveFailed` · `unknown`.
  `userMessage`는 토스트·얼럿 문구(임의 작성본 — 기획의 에러 문구 가이드가 나오면 교체한다)

### 이 모듈에 두지 않은 것

**스티커 배치** — 사진 위 어디에 붙는지는 `PhotoDetailFeature.StickerLayout`이 정한다.
격자·비워 두는 구간·기울기가 전부 시안 레이아웃에서 나온 값이고, 서버는 좌표를 주지 않는다. 도메인이
"사진 카드 위쪽에 촬영자 이름이 얹힌다"를 알 이유가 없어 화면 쪽에 뒀다. 서버가 좌표를 주기 시작하면
그때 `PhotoReaction`에 실어 도메인으로 들인다.

**표시 문구** — `PhotoError.userMessage`만 예외로 여기 있다. 얼럿 제목은 화면이 정하고 본문만
오류가 들고 있는 형태인데, `AuthError.userMessage`가 같은 방식이라 선례를 따랐다.
문구 정책이 정해지면 두 모듈을 함께 옮기는 게 맞다.

## 의존성

- **이 모듈이 의존**: `Dependencies` · `DependenciesMacros` (TCA 전이 의존 — `@DependencyClient` 키 선언)
- **이 모듈에 의존**: `PhotoDetailFeature`·`PhotoDetailFeatureDemo`·`CameraFeature`(UseCase를 `@Dependency`로
  주입받음) · `PhotoData`(인터페이스 구현) · 합성 루트(`CHALLAApp`·`CameraFeatureDemo`)

## 테스트 실행 방법

```bash
mise exec -- tuist test PhotoDomain
```

Swift Testing 기반 순수 유닛테스트(시뮬레이터 불필요). `Tests/Support/Mocks`의 목으로 인터페이스만
갈아끼워 검증한다.

- `PhotoReactionTests` — 켜기·끄기, 멱등성, 없는 것 끄기, 남의 리액션 보존, 종류별 누적, 중복 제거, 신원 규칙
- `PhotoUseCaseTests` — 방 ID 전달, 조회 실패 전파, 리액션 목표 상태 전달
- `SavePhotoUseCaseTests` — 바이트 전달, 내려받기 실패·권한 거부 전파, 취소 통과, 계약 밖 오류의 `unknown` 정규화
- `PhotoUseCasesLiveTests` — 카메라 필터·업로드 UseCase의 결과·인자 전달·오류 전파, 안내 노출 판단·기록

스티커 배치 테스트는 `PhotoDetailFeature`로 옮겼다 — 규칙이 그쪽에 있다.
