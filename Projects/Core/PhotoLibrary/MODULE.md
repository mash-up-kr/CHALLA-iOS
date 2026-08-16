# PhotoLibrary

## 레이어와 책임

**Core 레이어** (OS 접점). 기기 사진첩과 만나는 두 가지 일을 맡는다 — **접근 권한**과 **저장**.

- **권한**: `PHAuthorizationStatus`를 `PhotoLibraryAuthorization` 값으로 옮겨 담아, 상위 레이어가
  Photos 프레임워크를 직접 import 하지 않고도 권한 상태로 분기할 수 있게 한다.
  **사진을 고르는 UI는 이 모듈에 없다.** 피커 화면은 SwiftUI `PhotosPicker`가 그리고(앱과 분리된 프로세스),
  이 모듈은 그 앞단의 권한 요청만 책임진다.
- **저장**: 이미지 바이트를 사진첩에 추가한다. 권한 요청(`.addOnly`)과 저장이 전부이며,
  사진을 읽거나 목록을 훑는 기능은 없다.

도메인 프로토콜(`PhotoDomain.PhotoLibraryWriting`)을 여기서 채택하지 않는다 —
`Keychain`이 `TokenStore`를 모르는 것과 같은 이유로, Core는 OS만 감싸고 도메인 인터페이스에
맞추는 어댑터는 Data(또는 앱 조립 지점)가 만든다. `PhotoData`가 생기기 전까지는
`PhotoDetailFeatureDemo`의 `CompositionRoot`가 그 어댑터를 들고 있다.

## 공개 API

### 권한 (ProfileSetup 등 읽기·선택 앞단)

- `enum PhotoLibraryAuthorization: Sendable, Equatable` — `.authorized` / `.limited` / `.denied` / `.restricted` / `.notDetermined`
- `var allowsPicking: Bool` — 사진을 고를 수 있는 상태인지 (`.authorized` · `.limited`)
- `PhotoLibraryPermissionClient` (`@DependencyClient`)
  - `var request: @Sendable () async -> PhotoLibraryAuthorization` — 미결정이면 시스템 팝업, 결정된 상태면 그대로 반환
  - `liveValue` — `PHPhotoLibrary`에 `.readWrite`로 질의 (`.addOnly`는 읽기 권한을 주지 않는다)
  - `testValue` — 전부 미구현 (테스트가 필요한 것만 채워 쓴다) / `previewValue` — 항상 `.authorized`
  - `DependencyValues.photoLibraryPermission`

### 저장 (PhotoDetail 다운로드)

| API | 설명 |
| :-- | :-- |
| `PhotoLibraryStore` | `save(imageData:)` — 권한 요청까지 포함한 저장. `PHPhotoLibrary.requestAuthorization(for: .addOnly)` → `PHAssetCreationRequest`로 원본 바이트를 그대로 추가한다 (UIImage로 만들면 메타데이터가 날아가고 재인코딩된다) |
| `PhotoLibraryError` | `permissionDenied` · `saveFailed` |

## 사용하는 쪽에서 필요한 설정

권한을 쓰는 앱 타깃은 `Info.plist`에 용도별 키가 있어야 한다 — 없으면 요청 시점에 앱이 크래시한다.
Tuist에서는 `makeAppProject(additionalInfoPlist:)`로 넣는다.

- 읽기·선택(권한 질의): `NSPhotoLibraryUsageDescription`
- 저장(`PhotoLibraryStore`): `NSPhotoLibraryAddUsageDescription`

## 의존성

- **이 모듈이 의존**: `Photos`(시스템) · `Dependencies` · `DependenciesMacros`(권한 클라이언트용 — `PhotoLibraryStore`는 쓰지 않음)
- **이 모듈에 의존**: `ProfileSetupFeature` · `PhotoDetailFeatureDemo` · `CHALLAApp`(예정) · `PhotoData`(예정)

## 테스트 실행 방법

```bash
mise exec -- tuist test PhotoLibrary
```

Swift Testing 기반. 시스템 상태 매핑과 `allowsPicking` 판정을 검증한다
(실제 권한 팝업은 테스트에서 띄우지 않는다 — 그 경계가 `PhotoLibraryPermissionClient`다).
`PhotoLibraryStore`는 권한 팝업과 시스템 사진첩 상태에 의존해 유닛테스트가 없다 —
동작 확인은 사진 상세 데모앱에서 다운로드 → 권한 팝업 → 사진 앱 저장까지 눈으로 본다.
