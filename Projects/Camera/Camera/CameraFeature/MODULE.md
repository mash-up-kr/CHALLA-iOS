# CameraFeature

**레이어: Feature** — 방에 사진을 남기는 카메라 화면 하나를 담당한다.

뷰파인더(베젤·배율)·촬영 조작(플래시·셔터·카메라 전환)·필터 띠·방 선택 드로어·촬영 불가 안내를
한 리듀서로 다룬다. 상태 변경은 전부 `CameraFeature` 안에서 일어나고, 뷰는 렌더링과 `send(...)`만 한다.

## 지금 구현 범위

**UI만 구현돼 있다.** 서버 API와 AVFoundation 캡처는 아직 붙지 않았다.

- 방 목록 · 필터 목록 · 촬영 가능 여부(`captureAvailability`)는 **호출부가 `State`로 주입한다.**
  API가 생기면 Domain에 UseCase를 추가하고 `@Dependency`로 받아 채우는 형태로 바꾼다 (아키텍처 규칙 2).
- 뷰파인더에 들어갈 실제 카메라 프리뷰는 `CameraView(store:preview:)`의 `preview` 슬롯으로 주입한다.
  기본값은 `CameraPreviewPlaceholder`(단색 그라디언트)다.
- 셔터를 눌러 촬영이 허용되면 `Action.Delegate.captureRequested(roomID:filterID:)`가 나간다.
  실제 캡처·업로드는 이 delegate를 받는 쪽(App 또는 데모앱)이 붙인다.

## 공개 API

| 타입 | 설명 |
| :-- | :-- |
| `CameraFeature` | 화면 리듀서. `State` · `Action`(`view` / `delegate` / `toastDismissed`) |
| `CameraView<Preview>` | 화면 뷰. `init(store:preview:)` · `init(store:)`(플레이스홀더 프리뷰) |
| `CameraPreviewPlaceholder` | AVFoundation 연동 전 뷰파인더를 채우는 대역 뷰 |
| `CameraRoom` | 촬영 대상 방 (`id` · `name` · `remainingCards` · `totalCards` · `cardsLevel`) |
| `CameraCardsLevel` | 남은 장수 표시 단계 (`normal` · `low` · `unavailable`) |
| `CameraFilter` | 필터 항목 (`id` · `name`) |
| `CameraZoom` | 뷰파인더 배율 (`factor` · `label` · `range`) |
| `CameraCaptureAvailability` | 촬영 가능 여부 (`available` · `unavailable(viewportMessage:toastMessage:)` · `noCardsLeft`) |
| `CameraFlashMode` · `CameraPosition` | 플래시 켜짐/꺼짐 · 전후면 카메라 |

### State 주입 예

```swift
CameraView(
    store: Store(
        initialState: CameraFeature.State(
            rooms: rooms,
            selectedRoomID: "3",
            filters: filters,
            captureAvailability: .available
        )
    ) { CameraFeature() }
)
```

## 화면 동작

| 동작 | 결과 |
| :-- | :-- |
| 두 손가락 핀치 | 배율이 1x~8x 사이에서 연속으로 바뀌고 배지 문구가 따라간다 |
| 배율 배지 탭 | 1x → 2x → 3x → 1x 순환 |
| 플래시 버튼 | 켜짐 ↔ 꺼짐 (아이콘 `LightningOn` / `LightningOff`) |
| 필터 띠 스크롤 · 탭 | 선택 필터가 항상 화면 중앙에 물린다 |
| 방 이름 버튼 | 방 선택 드로어(`CHALLADrawer`)를 연다 |
| 셔터 (촬영 가능) | `delegate(.captureRequested)` |
| 셔터 (촬영 불가) | 서버가 준 문구로 토스트를 3초 띄운다. 뷰파인더는 안내 문구로 대체돼 있다 |

## 디자인 근거 (Zeplin)

| 화면 | 링크 |
| :-- | :-- |
| FlashOn | https://zpl.io/QMW0Rr9 |
| SelectRoom (드로어) | https://zpl.io/RmNMzyN |
| FlashOff | https://zpl.io/GnzEAx9 |
| 촬영 불가능 | https://zpl.io/xnBm6MX |

실측값은 `Sources/Components/CameraMetric.swift` 한 곳에 모아 둔다.

DS에 없는 형태(52pt 원형 아이콘 버튼, 44pt 알약 방 버튼)만 이 모듈에서 만들고,
드로어 껍데기·토스트·아이콘·색·타이포는 `CHALLADesignSystem`을 그대로 쓴다.

## 의존

- 의존하는 모듈: `CHALLADesignSystem`, `ComposableArchitecture`
- 이 모듈에 의존하는 모듈: `CameraFeatureDemo` (추후 `CHALLAApp`)

## 테스트

```bash
mise exec -- tuist test CameraFeature
```

`TestStore`로 플래시·카메라 전환·셔터(가능/불가)·배율(핀치·탭·범위·문구)·필터·방 선택·토스트 수명을 검증한다.

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

데모앱은 실기기 카메라를 실제로 붙인다 (`CameraSessionController` — `AVCaptureSession` 구성·촬영,
`delegate(.captureRequested)`를 받아 사진첩 Add-only 저장까지). 시뮬레이터에서는 프리뷰 자리에
`CameraPreviewPlaceholder`가 그대로 남는다.
