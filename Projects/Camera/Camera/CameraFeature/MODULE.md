# CameraFeature

**레이어: Feature** — 방에 사진을 남기는 카메라 화면 하나를 담당한다.

뷰파인더(베젤·배율)·촬영 조작(플래시·셔터·카메라 전환)·필터 띠·방 선택 드로어·촬영 불가 안내를
한 리듀서로 다룬다. 상태 변경은 전부 `CameraFeature` 안에서 일어나고, 뷰는 렌더링과 `send(...)`만 한다.

## 지금 구현 범위

**UI·필터(LUT)·서버 연동까지 구현돼 있다.** AVFoundation 캡처만 조립 지점 몫이다.

- 방 목록·필터 목록은 진입 시(`view(.task)`) 리듀서가 `@Dependency` UseCase로 직접 불러온다 —
  `FetchShootableRoomsUseCase`(RoomDomain, `GET /rooms/shootable`) ·
  `FetchCameraFiltersUseCase`/`LoadFilterLUTUseCase`(PhotoDomain, `GET /shoots/camera-filters`).
  촬영 가능 여부(`captureAvailability`)는 선택된 방의 남은 장수로 리듀서가 다시 계산한다.
- 필터 LUT는 내려받는 대로 `CameraFilterCatalog.register`로 등록되고 `preparedFilterIDs`에 표시된다.
  실제 색 변환은 조립 지점의 카메라 세션이 `CameraFilterCatalog`로 id를 LUT에 매핑해 수행한다.
- 뷰파인더에 들어갈 실제 카메라 프리뷰는 `CameraView(store:preview:)`의 `preview` 슬롯으로 주입한다.
  기본값은 `CameraPreviewPlaceholder`(단색 그라디언트)고, 실기기 연동 시에는
  `CameraFilteredPreviewView`(Metal 렌더러)에 `CameraPreviewFrameSource` 구현을 물려 넣는다.
- 셔터를 눌러 촬영이 허용되면 `Action.Delegate.captureRequested(roomID:filterID:)`가 나간다.
  하드웨어 캡처는 이 delegate를 받는 쪽(App 또는 데모앱)이 수행하고, 결과 JPEG을
  `Action.captureCompleted(roomID:filterID:jpegData:)`로 되돌려주면 리듀서가
  `UploadPhotoUseCase`(발급→스토리지 PUT→완료 통보)로 업로드한다. 응답의 `remainedPhotoCount`로
  그 방의 남은 장수를 갱신하고, 0이면 촬영을 막는다. 실패는 토스트로 알린다.

## 공개 API

| 타입 | 설명 |
| :-- | :-- |
| `CameraFeature` | 화면 리듀서. `State` · `Action`(`view` / 서버 응답 / `captureCompleted` / `delegate` / `toastDismissed`) |
| `CameraView<Preview>` | 화면 뷰. `init(store:preview:)` · `init(store:)`(플레이스홀더 프리뷰) |
| `CameraPreviewPlaceholder` | AVFoundation 연동 전 뷰파인더를 채우는 대역 뷰 |
| `CameraCardsLevel` | 남은 장수 표시 단계 (`normal` · `low` · `unavailable`) |
| `CameraFilterCatalog` | 서버에서 내려받은 LUT의 등록소. `register(cubeData:for:)`(다운로드 원자료 파싱·등록) · `lutFilter(id:)`(id → 새 `CIColorCube`) · `filteredJPEG(from:filterID:)`(촬영본 후처리) |
| `CameraFilteredPreviewView` | LUT 입힌 프레임(`CIImage`)을 Metal로 그리는 프리뷰 뷰 — `preview` 슬롯용 |
| `CameraPreviewFrameSource` | 프리뷰 프레임 공급자 프로토콜. 카메라 세션(조립 지점 소유)이 구현한다 |
| `CameraZoom` | 뷰파인더 배율 (`factor` · `label` · `range`) |
| `CameraCaptureAvailability` | 촬영 가능 여부 (`available` · `unavailable(viewportMessage:toastMessage:)` · `noCardsLeft`) |
| `CameraFlashMode` · `CameraPosition` | 플래시 켜짐/꺼짐 · 전후면 카메라 |

방·필터 모델은 이 모듈이 정의하지 않는다 — `RoomDomain.ShootableRoom` · `PhotoDomain.CameraFilter`를
그대로 상태에 담는다 (Feature → Domain, 아키텍처 규칙 1).

## 화면 동작

| 동작 | 결과 |
| :-- | :-- |
| 두 손가락 핀치 | 배율이 1x~8x 사이에서 연속으로 바뀌고 배지 문구가 따라간다 |
| 배율 배지 탭 | 1x → 2x → 3x → 1x 순환 |
| 플래시 버튼 | 켜짐 ↔ 꺼짐 (아이콘 `LightningOn` / `LightningOff`) |
| 필터 띠 스크롤 · 탭 | 선택 필터가 항상 화면 중앙에 물린다 |
| 방 이름 버튼 | 방 선택 드로어(`CHALLADrawer`)를 연다 |
| 셔터 (촬영 가능) | `delegate(.captureRequested)` → 조립 지점 캡처 → `captureCompleted` → 업로드·장수 갱신 |
| 셔터 (촬영 불가) | 서버가 준 문구로 토스트를 3초 띄운다. 뷰파인더는 안내 문구로 대체돼 있다 |

## 디자인 근거 (Zeplin)

| 화면 | 링크 |
| :-- | :-- |
| FlashOn | https://zpl.io/QMW0Rr9 |
| SelectRoom (드로어) | https://zpl.io/RmNMzyN |
| FlashOff | https://zpl.io/GnzEAx9 |
| 촬영 불가능 | https://zpl.io/xnBm6MX |

실측값은 컴포넌트별 파일 하단의 private metric enum에 둔다 (DS 컨벤션과 동일).

DS에 없는 형태(52pt 원형 아이콘 버튼, 44pt 알약 방 버튼)만 이 모듈에서 만들고,
드로어 껍데기·토스트·아이콘·색·타이포는 `CHALLADesignSystem`을 그대로 쓴다.

## 의존

- 의존하는 모듈: `CHALLADesignSystem`, `ComposableArchitecture`, `RoomDomain`, `PhotoDomain`
- 이 모듈에 의존하는 모듈: `CameraFeatureDemo` (추후 `CHALLAApp`)

## 테스트

```bash
mise exec -- tuist test CameraFeature
```

`TestStore`로 플래시·카메라 전환·셔터(가능/불가)·배율(핀치·탭·범위·문구)·필터 로드/선택·방 목록 로드/선택·업로드(장수 갱신·소진 차단·실패 토스트)·토스트 수명을 검증한다.

## 데모앱

`CameraFeatureDemo`는 실행 인자로 시안 상태를 바로 띄운다.

```bash
xcrun simctl launch booted com.challa.camerafeature.demo --screen camera --state default
```

| `--screen` | `--state` | 대응 시안 |
| :-- | :-- | :-- |
| `camera` | `default` | FlashOff |
| `camera` | `error` | 촬영 불가능 + 토스트 |

인자를 주지 않으면 시나리오 목록이 뜬다.
FlashOn·SelectRoom은 아직 인자로 띄우지 못한다 — 목록에서 들어간 뒤 직접 눌러 확인한다.

데모앱은 실기기 카메라를 실제로 붙인다 (`CameraSessionController` — `AVCaptureSession` 구성,
LUT 프리뷰 프레임 공급(`CameraPreviewFrameSource` 구현), 촬영본 필터 적용,
`delegate(.captureRequested)`를 받아 사진첩 Add-only 저장 후 `captureCompleted`로 되돌림).
시뮬레이터에서는 프리뷰 자리에 `CameraPreviewPlaceholder`가 그대로 남는다.

방·필터·업로드 데이터는 `CompositionRoot`가 InMemory 구현(RoomData·PhotoData)으로 꽂는다 —
로그인이 없어 실서버를 못 부르고, 필터 LUT는 코드에서 생성한 목 .cube 데이터로 제공한다
(실 LUT 원본은 서버에만 있고 저장소에는 .cube 파일을 두지 않는다).
실서버 배선은 `CHALLAApp`의 `CompositionRoot`에 이미 등록돼 있다.
