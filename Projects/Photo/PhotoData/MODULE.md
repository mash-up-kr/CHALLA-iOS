# PhotoData

## 레이어와 책임

**Data 레이어**. `PhotoDomain`의 두 인터페이스를 각각 실서버·메모리로 구현한다.

- `DefaultCameraFilterRepository` / `DefaultPhotoUploader` — **실서버 구현.** `CHALLANetwork`의
  `HTTPClient`로 서버·스토리지를 부르고, 실패를 `PhotoError`로 번역한다. 실배포앱이 쓴다
- `InMemoryCameraFilterRepository` / `InMemoryPhotoUploader` — **메모리 구현.** 데모앱이 네트워크·로그인
  없이 화면을 단독 실행하는 수단이라 실서버 구현이 있어도 지우지 않는다

어느 쪽을 쓸지는 합성 루트가 정한다 — `CHALLAApp`은 Default를, `CameraFeatureDemo`는 InMemory를 꽂는다.

## 공개 API

### Repository (`Sources/Repository/`)

- `struct DefaultCameraFilterRepository: CameraFilterRepository` — `init(client:)`
  - `filters()` — `GET /shoots/camera-filters` → 도메인 변환 (깨진 fileUrl은 `.unknown`)
  - `lutData(for:)` — 필터의 공개 URL에서 .cube 원본을 받는다. **토큰을 붙이지 않는다**
    (스토리지 공개 URL). 만료되지 않는 URL이라 세션 동안 메모리에 캐시해 재다운로드를 막는다
- `struct DefaultPhotoUploader: PhotoUploader` — `init(client:)`
  - `upload(jpegData:roomID:filterName:)` — 3단계를 한 호출로: `POST /uploads`(purpose `PHOTO`) →
    스토리지 PUT(서명 URL·5분 만료·Authorization 금지) → `POST /photos`(완료 통보) →
    응답의 `remainedPhotoCount` 반환. PUT 실패 시 완료 통보 없이 던진다 — 재시도는 발급부터
    (`DefaultProfileImageUploader`와 같은 구조)
- `struct InMemoryCameraFilterRepository: CameraFilterRepository` —
  `init(filters:lutDataByName:latency:failure:)`. 넘겨준 목록·LUT를 그대로 돌려준다
- `actor InMemoryPhotoUploader: PhotoUploader` — `init(remainedPhotoCounts:latency:failure:)`.
  방별 남은 장수를 실서버처럼 차감해 돌려주고, 소진된 방이면 `.photoExhausted`를 던진다
- `struct DefaultCameraOnboardingRepository: CameraOnboardingRepository` — `init(storage:)`
  (기본값 `UserDefaultsCameraOnboardingStorage`). 카메라 안내 노출 여부를 기기에 남긴다 —
  이 저장소만 서버를 타지 않는다
- `actor InMemoryCameraOnboardingRepository: CameraOnboardingRepository` — `init(hasSeen:)`.
  앱을 끄면 사라져 데모에서 안내를 매번 다시 볼 수 있다

### Storage (`Sources/Storage/`)

- `protocol CameraOnboardingStorage` · `struct UserDefaultsCameraOnboardingStorage` —
  `UserDefaults`를 한 겹 감싼다. 테스트가 실제 저장소를 건드려 서로 간섭하지 않게 하려는 것이며,
  `SettingData.SettingsStorage`와 같은 판단이다 (Data 모듈끼리 import하지 않으려고 따로 둔다)

## 내부 구성 (internal — 서버 계약이 바뀌면 여기만 바뀐다)

- `DTO/` — 스웨거 스키마와 1:1. `BaseResponseDTO`(공통 껍데기, UserData·RoomData 복사본 — #51에서
  통합), `CameraFiltersResponseDTO`(`{ shoot: { cameraFilters } }` 이중 껍데기),
  `CompletePhotoRequestDTO`/`CompletePhotoResponseDTO`, 업로드 DTO(UserData 복사본)
- `Endpoint/` — `ShootEndpoint`(cameraFilters `.bearer` · cubeFile 공개 URL `.none`),
  `PhotoEndpoint`(complete `.bearer`), `UploadEndpoint`(issue `.bearer` · put `.none`, UserData 복사본)
- `Mapping/PhotoError+Mapping` — `normalized`(취소는 통과, 401→unauthorized,
  409→photoExhausted는 잠정 — 스웨거에 에러 정의가 없음 TODO)

## 의존성

- **이 모듈이 의존**: `PhotoDomain`(인터페이스·엔티티·오류) · `CHALLANetwork`(HTTPClient·Endpoint)
- **이 모듈에 의존**: `CHALLAApp` · `CameraFeatureDemo` — 합성 루트만 import한다
  (아키텍처 규칙 2: Feature는 Data를 import하지 않는다)

## 테스트 실행 방법

```bash
mise exec -- tuist test PhotoData
```

Swift Testing 기반 순수 유닛테스트(시뮬레이터 불필요). `Tests/Support/MockHTTPClient`
(RoomData 것의 복사본)로 서버 없이 검증한다.

- `DefaultCameraFilterRepositoryTests` — 목록 경로·bearer 확인, `success:false` 언랩,
  LUT 무토큰 다운로드와 캐시(재호출 시 요청 1회), transport→`.network` 정규화
- `DefaultPhotoUploaderTests` — 발급→PUT→완료 3단계 순서와 각 단계의 인증·본문 계약,
  PUT 실패 시 완료 통보 생략, 409→`.photoExhausted` 잠정 매핑
- `InMemoryPhotoUploaderTests` — 차감·소진·주입 실패
- `DefaultCameraOnboardingRepositoryTests` — 기록 없음 = 미열람, 기록 후 유지, 앱 재실행 시 유지
  (`Tests/Support/InMemoryCameraOnboardingStorage`로 실제 `UserDefaults`를 건드리지 않는다)
