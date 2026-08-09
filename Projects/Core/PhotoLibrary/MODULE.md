# PhotoLibrary

## 레이어와 책임

**Core 레이어** (OS 접점). 사진 라이브러리 접근 **권한**만 다루는 모듈이다.
`PHAuthorizationStatus`를 `PhotoLibraryAuthorization` 값으로 옮겨 담아, 상위 레이어가 Photos 프레임워크를
직접 import 하지 않고도 권한 상태로 분기할 수 있게 한다.

**사진을 고르는 UI는 이 모듈에 없다.** 피커 화면은 SwiftUI `PhotosPicker`가 그리고(앱과 분리된 프로세스),
이 모듈은 그 앞단의 권한 요청만 책임진다.

`@DependencyClient`로 선언해 상위 레이어가 `@Dependency(\.photoLibraryPermission)`으로 주입받고
테스트에서는 값으로 교체한다.

## 공개 API

### PhotoLibraryAuthorization
- `enum PhotoLibraryAuthorization: Sendable, Equatable` — `.authorized` / `.limited` / `.denied` / `.restricted` / `.notDetermined`
- `var allowsPicking: Bool` — 사진을 고를 수 있는 상태인지 (`.authorized` · `.limited`)

### PhotoLibraryPermissionClient (`@DependencyClient`)
- `var request: @Sendable () async -> PhotoLibraryAuthorization` — 미결정이면 시스템 팝업, 결정된 상태면 그대로 반환
- `liveValue` — `PHPhotoLibrary`에 `.readWrite`로 질의 (`.addOnly`는 읽기 권한을 주지 않는다)
- `testValue` — 전부 미구현 (테스트가 필요한 것만 채워 쓴다)
- `previewValue` — 항상 `.authorized`
- `DependencyValues.photoLibraryPermission`

## 사용하는 쪽에서 필요한 설정

권한을 요청하는 앱 타깃은 `Info.plist`에 `NSPhotoLibraryUsageDescription`이 있어야 한다 —
없으면 요청 시점에 앱이 크래시한다. Tuist에서는 `makeAppProject(additionalInfoPlist:)`로 넣는다.

## 의존성

- **이 모듈이 의존**: `Photos`(시스템) · `Dependencies` · `DependenciesMacros`
- **이 모듈에 의존**: `ProfileSetupFeature` · `CHALLAApp`(예정)

## 테스트 실행 방법

```bash
mise exec -- tuist test PhotoLibrary
```

Swift Testing 기반. 시스템 상태 매핑과 `allowsPicking` 판정을 검증한다
(실제 권한 팝업은 테스트에서 띄우지 않는다 — 그 경계가 `PhotoLibraryPermissionClient`다).
