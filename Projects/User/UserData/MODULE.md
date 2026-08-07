# UserData

## 레이어와 책임

**Data 레이어**. `UserDomain`의 `UserRepository`를 구현한 **구체 어댑터**를 public으로 제공한다
(아키텍처 규칙 1: `Feature → Domain ← Data`).
이 모듈은 **구현체만 내놓고, 조립·주입은 하지 않는다** — 어댑터를 `FetchMyProfileUseCase.live(...)` ·
`SetupProfileUseCase.live(...)`에 넘기는 합성 루트는 상위(`CHALLAApp`의 `CompositionRoot`)에 있다.

담당 범위:
- **서버 통신** — `UserEndpoint`(`/api/v1/users/me` 하나를 GET·PUT·DELETE로 사용) +
  공통 응답 래퍼 `BaseResponseDTO` 언랩 + `NetworkError`와 서버 실패 응답(`success=false`)을
  `UserError`로 정규화 (`DefaultUserRepository`).
  baseURL은 `CHALLANetwork`의 `CHALLAAPIEnvironment.baseURL`(앱 전역 서버 값)을 그대로 쓴다.
- **`user` 키로 한 번 더 감싸기** — 요청·응답 본문이 `user` 키 안에 들어간다
  (`{"data":{"user":{...}}}` · `{"user":{...}}`). 서버 전역 규약이라 room·photo·chat·auth도 각자의 키를 쓴다.
  DTO마다 `user` 프로퍼티를 직접 두고 페이로드를 `Payload`로 중첩한다 — 별도 래퍼 타입을 만들지 않는다.
- **DTO ↔ 도메인 매핑** — `UserProfileResponseDTO.toDomain()`.
  `nickname`이 null이면 `UserProfile.nickname == nil`로 그대로 옮겨, 프로필 설정 완료 여부 판별의 근거가 된다.

**취소 처리**: `CancellationError`는 `UserError`로 뭉개지 않고 그대로 전파한다 —
호출자(리듀서)가 "실패 토스트를 띄울 오류"와 "화면을 떠나 취소된 작업"을 구분해야 하기 때문이다.

**동시성**: Swift 6 strict concurrency 기준, `@unchecked Sendable` 미사용.

## 공개 API

Feature가 볼 일 없는 세부 타입(Endpoint/DTO/Mapper)은 internal이고, 합성 루트가 조립에 쓰는 어댑터만 public이다:

- `struct DefaultUserRepository: UserRepository`
  - `init(client: any HTTPClient)` — 합성 루트가 구성한 `HTTPClient`를 주입
    (Auth와 **같은 클라이언트 인스턴스**를 넘겨야 `AuthInterceptor`가 붙인 Bearer 토큰이 실린다)
  - `fetchMyProfile()` — `GET /api/v1/users/me`
  - `updateProfile(nickname:imageURL:)` — `PUT /api/v1/users/me`. 이미지는 이미 올라간 공개 URL로 받는다
  - `deleteAccount()` — `DELETE /api/v1/users/me`
- `struct DefaultProfileImageUploader: ProfileImageUploader`
  - `init(client: any HTTPClient)` — 같은 클라이언트를 공유한다
  - `upload(_:Data) -> URL` — `POST /api/v1/uploads`로 서명 URL을 발급받아 스토리지에 직접 PUT하고 공개 URL을 돌려준다

## 서버 계약에서 온 제약

- **이미지 업로드는 3단계다** — `발급(POST /api/v1/uploads) → 스토리지 직접 PUT → PUT /api/v1/users/me`.
  서버는 파일을 받지 않고 서명 URL만 발급한다. 서버 규약에서 온 제약:
  - 스토리지 PUT에 **`Authorization` 헤더를 붙이면 서명이 깨져 403**이 난다 →
    `UploadEndpoint.put`의 `authorizationType`을 `.none`으로 두어 `AuthInterceptor`가 건너뛰게 한다
  - `Content-Type`이 발급 때 보낸 `contentType`과 **정확히 같아야** 한다(다르면 403)
  - 서명 URL은 경로·쿼리에 서명을 담고 있어 `path`를 비워 **그대로** 써야 한다
  - `uploadUrl`은 **5분 만료·1회용**이라 발급 직후 곧바로 올린다
  - 서버가 받는 MIME은 jpeg·png·webp뿐인데 사진 앱은 HEIC를 주는 경우가 많아
    **업로더가 JPEG로 다시 인코딩**해 한 종류로 맞춘다(`purpose`는 `PROFILE_IMAGE`)
  - **업로드가 실패하면 프로필 저장으로 넘어가지 않는다** — 스토리지 실패를 서버는 알지 못해
    사진 없는 프로필이 저장되고 사용자는 성공으로 오해한다. 순서 조립은 `SetupProfileUseCase.live`가 한다
- `UpdateProfileRequestDTO`는 `encode(to:)`를 직접 구현한다 — `profileImageUrl`이 required(nullable)라
  합성 인코딩처럼 nil일 때 키를 생략하면 서버가 거부한다.
- `GET /api/v1/users/nickname/random`은 서버에서 삭제되어 구현하지 않는다.

## 의존성

- **이 모듈이 의존**: `UserDomain`(인터페이스·엔티티·오류) · `CHALLANetwork`(HTTPClient·Endpoint)
- **이 모듈에 의존**: `CHALLAApp`(조립 지점 — 규칙 2의 예외)

## 테스트 실행 방법

```bash
mise exec -- tuist test UserData
```

Swift Testing 기반 (`MockHTTPClient` 한 종 — 경로·메서드·요청 본문을 캡처한다):

- `DefaultUserRepositoryTests` — 조회/설정/탈퇴의 경로·메서드 검증, 응답→도메인 매핑,
  `nickname: null` → `isProfileCompleted == false`, `PUT` 본문을 `user` 키로 감싸고 `profileImageUrl` 키 포함,
  `success=false`→`.server(message:)`, 401→`.unauthorized`, 전송 실패→`.network`,
  취소→`CancellationError` 그대로 전파
- `DefaultProfileImageUploaderTests` — 발급→PUT 2회 왕복, 발급 본문의 `upload` 키·`purpose`·`contentType`,
  스토리지 PUT의 Bearer 미부착·`Content-Type`, JPEG 재인코딩(SOI 마커), 디코딩 불가 입력 차단, 403·발급 실패 정규화
- `UploadEndpointTests` — 서명 URL을 그대로 쓰고 경로를 덧붙이지 않는다

> `MockHTTPClient`는 `endpoint.baseURL`을 읽지 않는다 — `CHALLAAPIEnvironment`가 Info.plist를 요구해
> 테스트 번들에서 접근하면 곧바로 죽는다. URL 규약은 `UploadEndpointTests`가 대신 고정한다.
