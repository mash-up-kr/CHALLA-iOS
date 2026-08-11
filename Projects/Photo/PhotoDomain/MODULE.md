# PhotoDomain

## 레이어와 책임

**Domain 레이어**. 방에서 찍힌 사진(Photo)과 리액션의 규칙을 담는다 —
엔티티, 저장소 인터페이스, 유스케이스, 도메인 오류가 전부다. 서버·사진첩·SwiftUI를 모른다.

사진 aggregate 하나에 Domain 한 벌이다 (아키텍처 규칙: Domain·Data는 화면이 아니라 aggregate 단위).
인화 전 필름은 여기 없다 — 인화 상태는 방의 상태라 `RoomDomain` 소관이고(`docs/ARCHITECTURE.md`),
이 모듈은 인화가 끝나 볼 수 있게 된 사진만 다룬다.

UseCase는 `AuthDomain`과 같은 방식으로 `liveValue`를 두지 않는다 — `TestDependencyKey`만 채택하고
`static func live(...)` 팩토리에 구현체를 넘겨 받는다. 인자 없는 `liveValue`를 만들려면 Domain이
Data를 import해야 해서 규칙 2가 깨지기 때문이다. 주입하지 않고 쓰면 런타임에 "no live implementation"이
뜨는데, 이는 의도된 설계다.

## 공개 API

### Entities

| 타입 | 내용 |
| :-- | :-- |
| `Photo` | `id` · `imageURL` · `author` · `capturedAt` · `reactions`. `hasReaction(_:by:)`로 내 리액션 여부를 묻고, `settingReaction(_:by:isOn:)`으로 리액션을 목표 상태에 맞춘 사본을 만든다(낙관적 갱신용). `init`에서 같은 신원의 리액션 중복을 걷어낸다 |
| `PhotoAuthor` | `id` · `nickname` · `avatarURL` — 사진에 박제된 시점의 촬영자 정보 |
| `ReactionKind` | 리액션 5종(medal · heart · poop · clap · skull). 시안 순서 그대로이며 이모지 글리프는 화면이 정한다 |
| `PhotoReaction` | `kind` · `userID` — 한 사람이 한 사진에 남긴 리액션 하나. `종류 + 사람`이 곧 `id`다. 스티커 좌표는 갖지 않는다 |

### Interface (구현은 Data · Core가 맡는다)

- `PhotoRepository` — `photos(inRoom:)` · `setReaction(photoID:kind:isOn:)` · `imageData(for:)`.
  실패는 전부 `PhotoError`로 정규화해 던지는 것이 구현체의 계약이다.
  리액션은 뒤집기가 아니라 **목표 상태를 지시하는 멱등 형태**다 — 같은 요청이 두 번 나가도 결과가
  같아야 재시도·취소가 안전하고, 화면이 먼저 그린 상태와 요청이 어긋나지 않는다
- `PhotoLibraryWriting` — `save(imageData:)`. 권한 요청까지 구현체 안에서 끝낸다

### UseCases (`DependencyValues` 키)

| 키 | live 팩토리 | 하는 일 |
| :-- | :-- | :-- |
| `\.fetchRoomPhotosUseCase` | `.live(repository:)` | 방의 사진을 찍힌 순서대로 가져온다 |
| `\.setPhotoReactionUseCase` | `.live(repository:)` | 리액션을 켜거나 끈 뒤 갱신된 사진을 돌려준다 |
| `\.savePhotoUseCase` | `.live(repository:photoLibrary:)` | 원본을 내려받아 사진첩에 저장한다. 계약을 어긴 오류가 새어 나와도 `PhotoError.unknown`으로 막는다 |

### Errors

- `PhotoError` — `network` · `server(message:)` · `permissionDenied` · `saveFailed` · `unknown`.
  `userMessage`는 얼럿 문구(임의 작성본 — 기획의 에러 문구 가이드가 나오면 교체한다)

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
- **이 모듈에 의존**: `PhotoDetailFeature` · `PhotoDetailFeatureDemo`
  (`PhotoData`는 아직 없다 — 서버 명세 확정 후 별도 이슈)

## 테스트 실행 방법

```bash
mise exec -- tuist test PhotoDomain
```

Swift Testing 18개:
- `PhotoReactionTests` — 켜기·끄기, 멱등성, 없는 것 끄기, 남의 리액션 보존, 종류별 누적, 중복 제거, 신원 규칙
- `PhotoUseCaseTests` — 방 ID 전달, 조회 실패 전파, 리액션 목표 상태 전달
- `SavePhotoUseCaseTests` — 바이트 전달, 내려받기 실패·권한 거부 전파, 취소 통과, 계약 밖 오류의 `unknown` 정규화

스티커 배치 테스트는 `PhotoDetailFeature`로 옮겼다 — 규칙이 그쪽에 있다.
