# PhotoLibrary

## 레이어와 책임

**Core 레이어** (OS 접점). Photos 프레임워크를 감싸 사진 라이브러리의 **권한**과 **저장**을 다룬다.
상위 레이어가 Photos를 직접 import 하지 않고도 권한으로 분기하고 사진을 저장할 수 있게 한다.

두 가지 일을 한다.

1. **권한** — `PHAuthorizationStatus`를 `PhotoLibraryAuthorization` 값으로 옮겨 담고, 요청까지 대신한다.
   사진을 고르는 UI는 없다 — 피커는 SwiftUI `PhotosPicker`가 그리고, 이 모듈은 그 앞단의 권한만 책임진다.
2. **저장** — 기기 사진첩에 이미지 바이트를 추가한다.

도메인 프로토콜(`PhotoDomain.PhotoLibraryWriting`)을 여기서 채택하지 않는다 —
`Keychain`이 `TokenStore`를 모르는 것과 같은 이유로, Core는 OS만 감싸고 도메인 인터페이스에
맞추는 어댑터는 Data(또는 앱 조립 지점)가 만든다. `PhotoData`가 생기기 전까지는
`PhotoDetailFeatureDemo`의 `CompositionRoot`가 그 어댑터(`PhotoLibraryWriting` → `PhotoLibraryStore`)를 들고 있다.

### `.readWrite`와 `.addOnly` — 언제 무엇을 쓰나

| 접근 수준 | 쓰는 API | 쓰는 곳 | 이유 |
| :-- | :-- | :-- | :-- |
| `.readWrite` | `PhotoLibraryPermissionClient` | 프로필 사진 선택(`ProfileSetupFeature`) | 사진을 **읽어야** 한다. `.addOnly`는 읽기 권한을 주지 않는다 |
| `.addOnly` | `PhotoLibraryStore` | 사진 상세 다운로드(`PhotoDetailFeature`) | **저장만** 한다. `.readWrite`를 물으면 "모든 사진 접근"을 요구해 거부율이 올라간다 |

> **주의**: iOS는 두 접근 수준의 권한 상태를 따로 들고 있지 않다 — 하나의 라이브러리 권한을 공유한다.
> 사용자가 프로필에서 `.readWrite`를 거부한 뒤 사진 상세에서 다운로드를 누르면, `.addOnly` 요청이
> 팝업 없이 바로 거부로 떨어질 수 있다. 두 진입점의 실패 문구가 서로 다른 화면을 가리키지 않도록 주의한다.

## 공개 API

### 권한 — `PhotoLibraryAuthorization`
- `enum PhotoLibraryAuthorization: Sendable, Equatable` — `.authorized` / `.limited` / `.denied` / `.restricted` / `.notDetermined`
- `var allowsPicking: Bool` — 사진을 고를 수 있는 상태인지 (`.authorized` · `.limited`)

### 권한 — `PhotoLibraryPermissionClient` (`@DependencyClient`)
- `var request: @Sendable () async -> PhotoLibraryAuthorization` — 미결정이면 시스템 팝업, 결정된 상태면 그대로 반환
- `liveValue` — `PHPhotoLibrary`에 `.readWrite`로 질의
- `testValue` — 전부 미구현 (테스트가 필요한 것만 채워 쓴다) · `previewValue` — 항상 `.authorized`
- `DependencyValues.photoLibraryPermission`

### 저장 — `PhotoLibraryStore`
- `func save(imageData: Data) async throws` — 권한 요청(`.addOnly`)까지 포함한 저장.
  `PHAssetCreationRequest`로 **원본 바이트를 그대로** 추가한다 (UIImage로 만들면 메타데이터가 날아가고 재인코딩된다).
  `.authorized`·`.limited` 둘 다 저장을 진행한다
- `enum PhotoLibraryError: Sendable, Equatable` — `permissionDenied` · `saveFailed`

권한을 요청·저장하는 앱 타깃은 `Info.plist`에 해당 usage description이 있어야 한다 — 없으면 요청 시점에 앱이 죽는다.
- 읽기(`.readWrite`) → `NSPhotoLibraryUsageDescription`
- 저장(`.addOnly`) → `NSPhotoLibraryAddUsageDescription`

Tuist에서는 `makeAppProject(additionalInfoPlist:)`로 넣는다.

## 의존성

- **이 모듈이 의존**: `Photos`(시스템) · `Dependencies` · `DependenciesMacros`
- **이 모듈에 의존**: `ProfileSetupFeature`(권한) · `PhotoDetailFeatureDemo`(저장) · `CHALLAApp`·`PhotoData`(예정)

## 테스트 실행 방법

```bash
mise exec -- tuist test PhotoLibrary
```

Swift Testing 기반. **권한** 쪽 — 시스템 상태 매핑과 `allowsPicking` 판정을 검증한다
(실제 권한 팝업은 테스트에서 띄우지 않는다 — 그 경계가 `PhotoLibraryPermissionClient`다).
**저장** 쪽(`PhotoLibraryStore`) — 권한 팝업과 시스템 사진첩 상태에 의존해 유닛테스트로 고정할 순수 로직이 없다.
동작 확인은 `PhotoDetailFeatureDemo`를 시뮬레이터에서 실행해 다운로드 → 권한 팝업 → 사진 앱 저장까지 눈으로 본다.
