# CameraSession

**레이어: Feature 조립 보조** — `CameraFeature`에 실기기 카메라(AVFoundation)를 붙이는 배선만 담는다.

`CameraFeature`는 하드웨어를 모른다 — 셔터가 눌리면 `delegate(.captureRequested)`만 내보내고,
실제 촬영은 조립 지점이 맡는다는 설계다. 그 "조립 지점이 할 일"이 실행 앱과 데모앱에서 똑같아서
양쪽이 복사하지 않도록 이 모듈로 모았다.

## 공개 API

| 타입 | 설명 |
| :-- | :-- |
| `LiveCameraFeature` | `CameraFeature`를 감싼 리듀서. `delegate(.captureRequested)` → 촬영·사진첩 저장 → `captureCompleted`로 되돌림. 촬영 실패는 카메라 화면의 토스트로 3초 노출 |
| `LiveCameraPreview` | `CameraView`의 `preview` 슬롯에 넣는 뷰. 세션 시작·정지를 뷰 생명주기에 맞추고 카메라 전환·줌·필터를 상태 변화대로 반영한다 |
| `CameraSessionController` | `AVCaptureSession` 구성·프레임 공급·촬영·저장. `\.cameraSession` 의존성으로 주입되며 리듀서와 프리뷰가 같은 인스턴스를 본다 |
| `PhotoLibrarySaver` | 촬영본을 사진첩에 추가한다 (`.addOnly` 권한만 요청) |
| `CameraSessionError` | 촬영 데이터 생성 실패 |

## 권한

**카메라 권한은 이 모듈이 묻지 않는다.** 화면에 들어왔다는 것은 진입 버튼(홈의 촬영 뱃지)이
이미 허용을 받아 뒀다는 뜻이라, `start(position:)`은 허용된 상태를 전제로 세션을 구성한다.
권한 요청은 `PhotoDomain.CameraPermissionProvider`(구현: `PhotoData`)가 맡는다.

사진첩 권한만 예외로 저장 직전에 요청한다 — 촬영 전에는 필요 없는 권한이라 미리 묻지 않는다.

실행 앱 Info.plist에 `NSCameraUsageDescription`·`NSPhotoLibraryAddUsageDescription`이 있어야 한다
(없으면 접근하는 순간 크래시한다).

## 의존

- 의존하는 모듈: `CameraFeature`, `PhotoDomain`, `ComposableArchitecture`
- 이 모듈에 의존하는 모듈: `CHALLAApp`, `CameraFeatureDemo`

## 테스트

유닛테스트를 두지 않는다 — 실기기 카메라·사진첩이 있어야 의미가 있어 시뮬레이터에서 검증되지 않는다.
리듀서 쪽 동작(촬영 요청 → 업로드)은 `CameraFeature`의 TestStore 테스트가 덮는다.
