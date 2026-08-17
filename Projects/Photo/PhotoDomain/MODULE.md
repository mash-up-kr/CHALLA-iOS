# PhotoDomain

## 레이어와 책임

**Domain 레이어**. 사진 촬영·업로드에 관한 순수 도메인 모듈이다 — 서버가 내려주는 카메라 필터,
사진 업로드 인터페이스, Feature-facing UseCase를 정의한다. 서버·스토리지의 존재를 모르며
(import는 `Foundation` + `Dependencies`/`DependenciesMacros`뿐), 인터페이스 구현은 `PhotoData`가
맡는다 (아키텍처 규칙 1: `Feature → Domain ← Data`).

**화면이 아니라 대상 단위로 한 벌이다.** 카메라·(추후) 사진 상세 등 사진을 다루는 Feature가 이 모듈을
공유한다 (`RoomDomain`과 같은 원칙 — `docs/ARCHITECTURE.md`의 "Camera는 Room·Photo·Core 재사용").

**의존 주입 설계**: UseCase는 `@DependencyClient` + `TestDependencyKey`로 선언하고 `liveValue`를
의도적으로 두지 않는다 — 조립은 합성 루트가 `.live(repository:)`/`.live(uploader:)`로 한다
(`RoomDomain`과 같은 구조, 이유는 그쪽 MODULE.md 참고).

## 공개 API

### Entities (`Sources/Entities/`)

- `struct CameraFilter` — 서버가 내려주는 카메라 필터 한 개 (`GET /shoots/camera-filters` 응답 한 줄).
  `name`(식별자 겸 표시 이름 — 사진 업로드 API도 이 값으로 필터를 가리킨다) · `fileURL`(LUT .cube 공개 URL)
  - `previewFilters` — 화면 확인용 샘플 (URL은 유효하지 않은 자리표시자)

### Errors (`Sources/Errors/`)

- `enum PhotoError` — `.network` · `.unauthorized` · `.photoExhausted`(방의 남은 장수 소진) ·
  `.server(message:)` · `.unknown`
  - `userMessage` — 토스트·얼럿 문구. 기획 가이드 확정 전까지는 임의 작성본이다

### Interface (`Sources/Interface/` — 구현: PhotoData)

- `protocol CameraFilterRepository` — `filters() -> [CameraFilter]` · `lutData(for:) -> Data`
  - LUT 파싱·CoreImage 변환은 호출부(화면 조립) 몫 — Domain·Data는 색 변환 기술을 모른다
- `protocol PhotoUploader` — `upload(jpegData:roomID:filterName:) -> Int`(그 방의 남은 장수)
  - 서명 URL 발급 → 스토리지 PUT → 완료 통보의 다단계 절차를 한 호출로 감춘다
    (`ProfileImageUploader`와 같은 구조)
  - 구현체 계약: 실패는 반드시 `PhotoError`로 정규화해 던진다
- `protocol CameraOnboardingRepository` — `hasSeenCoachMark() -> Bool` · `markCoachMarkSeen()`
  - 카메라 진입 안내를 이미 봤는지 기억한다. 기기에만 남기고 서버에 올리지 않는다
- `protocol CameraPermissionProvider` — `requestAccess() -> Bool` · `openSystemSettings()`
  - 촬영 진입 버튼이 목록 조회와 함께 권한을 받아 둔다. 이미 거절한 뒤에는 다시 물을 수 없어
    `false`가 오고, 호출부가 설정 앱으로 안내한다

### UseCases (`@DependencyClient` — `liveValue` 없음)

- `FetchCameraFiltersUseCase` (`\.fetchCameraFiltersUseCase`) — 필터 목록 조회 (`-> [CameraFilter]`)
- `LoadFilterLUTUseCase` (`\.loadFilterLUTUseCase`) — 필터 하나의 LUT 원본 바이트 (`-> Data`)
- `UploadPhotoUseCase` (`\.uploadPhotoUseCase`) — 사진 업로드 후 남은 장수 (`-> Int`)
- `ShouldShowCameraCoachMarkUseCase` (`\.shouldShowCameraCoachMarkUseCase`) — 카메라 최초 진입인지 (`-> Bool`)
- `MarkCameraCoachMarkSeenUseCase` (`\.markCameraCoachMarkSeenUseCase`) — 안내를 끝까지 본 것으로 기록
- `RequestCameraPermissionUseCase` (`\.requestCameraPermissionUseCase`) — 카메라 접근 허용 여부 (`-> Bool`)
- `OpenCameraSettingsUseCase` (`\.openCameraSettingsUseCase`) — 설정 앱의 이 앱 화면 열기

전부 `static func live(...)` · `testValue` · `previewValue`를 갖는다.
안내·권한 관련 넷은 기기 저장값과 OS 권한만 다뤄 실패 개념이 없다 — 던지지 않는다.

## 의존성

- **이 모듈이 의존**: `Dependencies` · `DependenciesMacros` (TCA 전이 의존, `Tuist/Package.swift` 경유)
- **이 모듈에 의존**: `CameraFeature`(UseCase를 `@Dependency`로 주입받음) ·
  `PhotoData`(인터페이스 구현) · 합성 루트(`CHALLAApp`·`CameraFeatureDemo`)

## 테스트 실행 방법

```bash
mise exec -- tuist test PhotoDomain
```

Swift Testing 기반 순수 유닛테스트(시뮬레이터 불필요). `Tests/Support/Mocks`의
`MockCameraFilterRepository`·`MockPhotoUploader`·`MockCameraOnboardingRepository`로
인터페이스만 갈아끼워 검증한다.

- `PhotoUseCasesLiveTests` — UseCase들의 결과 전달·인자 전달·오류 전파, 안내 노출 판단·기록
