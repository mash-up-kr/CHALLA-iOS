# AppData

## 레이어와 책임

**Data 레이어**. `AppDomain`의 `AppVersionRepository`를 실서버로 구현한다.
메모리 구현이 없는 이유: 버전 체크는 데모앱이 쓰지 않는다 — 데모는 화면 하나를
단독 실행하는 수단이라 앱 수준 진입 판정이 없다.

## 공개 API

- `struct DefaultAppVersionRepository: AppVersionRepository` — `init(client:)`
  - `checkUpdateRequirement(currentVersion:)` — `GET /api/v1/app/version?os=IOS&version=<현재>` →
    `updateRequired`면 `.forced(storeURL:)`, 아니면 `.notRequired`.
    스토어 주소가 URL이 안 되면(미등록 상태의 빈 문자열 등) nil로 접는다 —
    화면은 막되 '확인'은 아무 것도 열지 않는다
  - **토큰을 붙이지 않는다** — 로그인 전(스플래시)에 부르는 공개 API다
  - `updateAvailable`·`latestVersion`은 받기만 하고 안 쓴다 — 권장 업데이트 정책 부재
    (`AppUpdateRequirement` 주석 참고)

## 내부 구성 (internal — 서버 계약이 바뀌면 여기만 바뀐다)

- `DTO/` — `BaseResponseDTO`(공통 껍데기, UserData 복사본 — #51에서 통합),
  `AppVersionResponseDTO`(`{ app: { ... } }` 이중 껍데기)
- `Endpoint/AppEndpoint` — `version` (`.none` 인증)

## 의존성

- **이 모듈이 의존**: `AppDomain`(인터페이스·엔티티) · `CHALLANetwork`(HTTPClient·Endpoint)
- **이 모듈에 의존**: `CHALLAApp` — 합성 루트만 import한다 (아키텍처 규칙 2)

## 테스트 실행 방법

```bash
mise exec -- tuist test AppData
```

Swift Testing 기반 순수 유닛테스트. `Tests/Support/MockHTTPClient`(RoomData 복사본)로 서버 없이 검증한다.

- `DefaultAppVersionRepositoryTests` — 쿼리·무토큰 계약, `updateRequired` 매핑,
  깨진 스토어 주소 nil 폴딩, `success:false` 던지기
