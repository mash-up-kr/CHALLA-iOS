# CameraFeature

**레이어: Feature** — 방에 사진을 남기는 카메라 화면 하나를 담당한다.

뷰파인더(베젤·배율)·촬영 조작(플래시·셔터·카메라 전환)·필터 띠·남은 장수·촬영 불가 안내를
한 리듀서로 다룬다. 상태 변경은 전부 `CameraFeature` 안에서 일어나고, 뷰는 렌더링과 `send(...)`만 한다.

## 지금 구현 범위

**UI·필터(LUT)·서버 연동까지 구현돼 있다.** AVFoundation 캡처는 `CameraSession` 모듈이 붙인다.

- **이 화면은 아무것도 조회하지 않는다.** 방 목록·필터 목록·필터 LUT를 진입 버튼(홈의 촬영 뱃지 ·
  방 상세의 사진 찍기)이 미리 받아 두고, 전부 성공했을 때만 `State(rooms:filters:)`로 넘기며
  들어온다. 실패하면 애초에 이 화면으로 넘어오지 않으므로, 여기에는 로딩·조회 실패 상태가 없다.
  방 선택은 화면에서 없앴다 (시안 '1.촬영 전') — 방은 진입 경로가 정하고 이 화면에서는 바꿀 수 없다.
  준비는 두 진입 버튼이 `ShootEntry` 모듈의 `ShootPreparation`으로 함께 한다 —
  쓰는 UseCase는 `FetchShootableRoomsUseCase`(RoomDomain, `GET /rooms/shootable`) ·
  `FetchCameraFiltersUseCase` · `PrepareCameraFiltersUseCase`(PhotoDomain)다.
  방 상세처럼 방이 정해진 경로는 `selectedRoomID`를 함께 넘긴다 — 그 방이 선택된 채로 열린다.
- 촬영 가능 여부(`captureAvailability`)는 선택된 방의 남은 장수에서 나오는 계산값이라 따로 들고 있지 않는다.
- **LUT(.cube)도 진입 전에 전부 등록된 상태로 들어온다.** 진입 버튼이 `PrepareCameraFiltersUseCase`에
  `CameraFilterCatalog.register`를 넘겨 주고, 열 개 남짓을 동시에 받아 하나라도 실패하면 진입을 막는다 —
  일부만 준비된 채로 들어가면 그 필터만 색이 안 먹는데, 사용자에게는 앱이 고장 난 것으로 보인다.
  실제 색 변환은 조립 지점의 카메라 세션이 `CameraFilterCatalog`로 id를 LUT에 매핑해 수행한다.
- 뷰파인더에 들어갈 실제 카메라 프리뷰는 `CameraView(store:preview:)`의 `preview` 슬롯으로 주입한다.
  기본값은 `CameraPreviewPlaceholder`(단색 그라디언트)고, 실기기 연동 시에는
  `CameraFilteredPreviewView`(Metal 렌더러)에 `CameraPreviewFrameSource` 구현을 물려 넣는다.
- 셔터를 눌러 촬영이 허용되면 `Action.Delegate.captureRequested(roomID:filterID:)`가 나간다.
  **필터 없는 촬영은 없다** — 목록 맨 앞에 무필터(`CameraFilter.none`)가 고정으로 붙고 진입 시 그것이 선택된다.
  하드웨어 캡처는 이 delegate를 받는 쪽(`CameraSession`의 `LiveCameraFeature`)이 수행하고, 결과 JPEG을
  `Action.captureCompleted(roomID:filterID:jpegData:)`로 되돌려주면 리듀서가
  `UploadPhotoUseCase`(발급→스토리지 PUT→완료 통보)로 업로드한다. 응답의 `remainedPhotoCount`로
  그 방의 남은 장수를 갱신하고, 0이면 촬영을 막는다. 실패는 토스트로 알리며 연출도 함께 풀린다.
- **셔터를 누른 순간부터 화면은 촬영 연출로 바뀐다** (시안 '2.촬영 버튼 클릭 시') — 뷰파인더만 남기고
  나머지가 사라지면서 뷰파인더가 화면 세로 가운데로 내려간다. `State.capture`(`CaptureProgress`)가
  이 구간을 나타내고, 그동안 셔터는 잠긴다.
  **연출 동안 뷰파인더는 라이브 프리뷰가 아니라 촬영본 한 장에 고정된다** — 기기를 움직여도 화면은 그대로다.
  `captureCompleted`로 돌아온 JPEG(=서버에 올라가는 그 사진)을 `capture.photoData`에 담아 뷰파인더가 그린다.
  스틸 촬영은 셔터음이 난 뒤 수백 ms가 지나야 끝나므로, 그동안은 **프리뷰를 얼려서** 메운다 —
  조립 지점의 프리뷰(`CameraFilteredPreviewView(source:isFrozen:)`)가 `isCapturing` 동안 새 프레임을
  버리고 마지막 프레임을 그대로 다시 그린다. 그래서 셔터를 누른 순간부터 화면이 멈춰 있고,
  촬영본이 도착하면 같은 장면이 그 사진으로 조용히 바뀐다.
  연출은 **업로드 완료**와 **최소 노출 1초**가 둘 다 차야 끝나고, 그때
  `delegate(.captureFinished(roomID:))`가 나간다 — 업로드가 순식간에 끝나도 연출이 한 번은 보인다.
  이 delegate를 받은 App은 그 방의 상세로 넘어가며, 방금 올린 사진을 강조하라고 알린다
  (시안 '3.촬영 이후 상세 화면' · '4.촬영 이후 상세 화면 강조 효과').
- 화면을 닫는 수단은 **화면 맨 아래 닫기 버튼뿐이다** (시안 '1.촬영 전').
  누르면 `delegate(.closeRequested)`가 나가고, 어디로 돌아갈지는 App이 정한다.
  이전의 위·아래 스와이프 닫기는 없앴다 — 버튼이 생겨 제스처를 겸할 이유가 없어졌고,
  제스처만 있을 때 스위치 제어·Voice Control에서 닫을 길이 없던 문제도 함께 사라진다.
- **카메라에 처음 들어왔을 때만** 잠깐 뜸을 들인 뒤 온보딩 안내 스낵바가 2단계로 뜬다
  (`CameraCoachMark` — 시안 camera_snackBar_1·2). 안내 중에는 뷰파인더를 흐리고 어둡게 덮고,
  필터 띠·하단 블록의 밝기를 낮추면서 조작도 막고, 셔터에 글로우를 두른다.
  액션("다음" → "확인")을 눌러야 넘어가며, 마지막 단계를 넘기면 사라지면서
  `MarkCameraCoachMarkSeenUseCase`로 기록돼 다음 진입부터는 뜨지 않는다.
  진입 시 노출 여부는 `ShouldShowCameraCoachMarkUseCase`(PhotoDomain)가 판단한다 —
  기록은 기기에만 남는다(`CameraOnboardingRepository`). 상태의 `hasStartedCoachMark`는
  한 화면 수명 안에서 조회가 되풀이되는 것만 막는 별도 장치다.

## 공개 API

| 타입 | 설명 |
| :-- | :-- |
| `CameraFeature` | 화면 리듀서. `State(rooms:filters:selectedRoomID:…)`(방·필터는 필수 — 진입 전에 받아 넘긴다) · `Action`(`view` / `coachMarkDelayElapsed` / `minimumCaptureDisplayElapsed` / `captureCompleted` / `uploadResponse` / `delegate` / `toastDismissed`) |
| `CameraFeature.CaptureProgress` | 촬영 연출의 진행 상태. 끝나는 조건 둘(`isMinimumDisplayElapsed` · `uploadedRoomID`)과 뷰파인더에 고정할 촬영본(`photoData`) |
| `CameraView<Preview>` | 화면 뷰. `init(store:preview:)` · `init(store:)`(플레이스홀더 프리뷰) |
| `CameraPreviewPlaceholder` | `preview` 슬롯을 주입하지 않았을 때 뷰파인더를 채우는 대역 뷰 (프리뷰·시뮬레이터용) |
| `CameraCardsLevel` | 남은 장수 표시 단계 (`normal` · `low` · `unavailable`) |
| `CameraCoachMark` | 온보딩 안내 단계 (`shutterCost` · `shutterCaution`). 단계별 `message` · `actionTitle` |
| `CameraFilterCatalog` | 서버에서 내려받은 LUT의 등록소. `register(cubeData:for:)`(다운로드 원자료 파싱·등록 — 진입 준비가 부른다) · `lutFilter(id:)`(id → 새 `CIColorCube`) · `filteredJPEG(from:filterID:)`(촬영본 후처리 — JPEG 품질 1.0으로 굽는다. 업로드 상한은 `CHALLAImageKit.ImageCompressor`가 맞추므로 여기서 미리 깎지 않는다) |
| `CameraFilteredPreviewView` | LUT 입힌 프레임(`CIImage`)을 Metal로 그리는 프리뷰 뷰 — `preview` 슬롯용. `isFrozen`이면 새 프레임을 버려 화면을 멈춘다 |
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
| 플래시 버튼 | 켜짐 ↔ 꺼짐 (아이콘 `LightningOn` / `LightningOff`). 진입 시 기본값은 꺼짐이고, 화면을 나가면 초기화된다 |
| 필터 띠 스크롤 · 탭 | 선택 필터가 항상 화면 중앙에 물린다. 맨 앞은 항상 무필터(`None`)이며 진입 시 선택돼 있다 |
| 방 이름 버튼 | 방 선택 드로어(`CHALLADrawer`)를 연다 |
| 셔터 (촬영 가능) | `delegate(.captureRequested)` → 조립 지점 캡처 → `captureCompleted` → 업로드·장수 갱신. 촬영본이 돌아오기 전까지 셔터가 잠겨 연타해도 한 번만 나간다 |
| 셔터 (촬영 불가) | 서버가 준 문구로 토스트를 3초 띄운다. 뷰파인더는 안내 문구로 대체돼 있다 |
| 안내 스낵바 액션 | 1단계("다음") → 2단계("확인") → 안내 종료. 안내 중에는 다른 조작이 막힌다 |
| 위·아래 스와이프 | 손가락을 따라 화면이 밀리고, 충분히 끌면 `delegate(.closeRequested)`로 닫기를 요청한다. 뷰파인더 위에서도 핀치 줌과 함께 동작한다 |

## 의존

- 의존하는 모듈: `CHALLADesignSystem`, `ComposableArchitecture`, `RoomDomain`, `PhotoDomain`
- 이 모듈에 의존하는 모듈: `CameraSession`(실기기 배선) · `CHALLAApp` · `CameraFeatureDemo`

## 테스트

```bash
mise exec -- tuist test CameraFeature
```

`TestStore`로 플래시·카메라 전환·셔터(가능/불가/방 없음/서버 필터 없음)·배율(핀치·탭·범위·문구)·진입 상태(첫 방 선택·지정 방·소진 방)·필터/방 선택(무필터 고정·중복 제거)·업로드(장수 갱신·소진 차단·실패 토스트)·토스트 수명·닫기 스와이프·온보딩 안내(뜸 후 노출·단계 진행·재노출 차단)를 검증한다.
`CameraFilterCatalogTests`는 .cube 등록의 성공·실패를 따로 본다 — 이 반환값이 카메라 진입 여부를 가른다.

## 데모앱

`CameraFeatureDemo`는 실행 인자로 시안 상태를 바로 띄운다.

```bash
xcrun simctl launch booted com.challa.camerafeature.demo --screen camera --state default
```

| `--screen` | `--state` | 대응 시안 |
| :-- | :-- | :-- |
| `camera` | `default` | FlashOff |
| `camera` | `coach` | 최초 진입 안내 (camera_snackBar_1 → "다음" → camera_snackBar_2) |
| `camera` | `error` | 촬영 불가능 + 토스트 |

인자를 주지 않으면 시나리오 목록이 뜬다.
FlashOn·SelectRoom은 아직 인자로 띄우지 못한다 — 목록에서 들어간 뒤 직접 눌러 확인한다.

실기기 카메라 배선은 실행 앱과 공유한다 (`CameraSession` 모듈 — `LiveCameraFeature`가
`delegate(.captureRequested)`를 받아 촬영 후 `captureCompleted`로 되돌리고,
`LiveCameraPreview`가 `preview` 슬롯을 채운다). 시뮬레이터에는 카메라가 없어 프리뷰가 비어 보인다.

진입 경로도 실앱과 같은 모양으로 재현한다 — `CameraEntryView`가 카메라를 띄우기 전에
방 목록과 필터(목록·LUT)를 먼저 받고, 전부 성공했을 때만 `CameraView`로 넘어간다(실패하면 그 자리에서 알린다).
실앱에서 홈·방 상세의 진입 버튼이 `ShootEntry`로 하는 일을 데모에서는 이 화면이 대신한다.

방·필터·업로드 데이터는 `CompositionRoot`가 InMemory 구현(RoomData·PhotoData)으로 꽂는다 —
로그인이 없어 실서버를 못 부르고, 필터 LUT는 코드에서 생성한 목 .cube 데이터로 제공한다
(실 LUT 원본은 서버에만 있고 저장소에는 .cube 파일을 두지 않는다).
실서버 배선은 `CHALLAApp`의 `CompositionRoot`에 이미 등록돼 있다.
