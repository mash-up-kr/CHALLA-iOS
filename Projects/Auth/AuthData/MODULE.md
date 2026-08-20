# AuthData

## 레이어와 책임

**Data 레이어**. `AuthDomain`의 인터페이스 4개(`AuthRepository`·`SocialLoginService`·`TokenStore`·`LaunchStateStore`)와
`CHALLANetwork`의 `TokenProvider`·`TokenRefreshing`을 구현한
**구체 어댑터**를 public으로 제공한다 (아키텍처 규칙 1: `Feature → Domain ← Data`).
이 모듈은 **구현체만 내놓고, 조립·주입은 하지 않는다** — 어댑터를 모아 `LoginUseCase.live(...)`로 완성하는
합성 루트는 상위(`CHALLAApp`·`LoginFeatureDemo`의 `CompositionRoot`)에 있다.
오케스트레이션(소셜→서버→저장 순서)도 Domain 소유다.

담당 범위:
- **서버 통신** — `AuthEndpoint`(login/refresh/logout, POST) + 공통 응답 래퍼 `BaseResponseDTO` 언랩 +
  `NetworkError`와 서버 실패 응답(`success=false`)을 `AuthError`로 정규화 (`DefaultAuthRepository`).
  요청·응답 본문은 `auth` 키로 한 번 더 감싸인다(서버 전역 규약 — user·room·photo·chat도 각자의 키를 쓴다).
  DTO마다 `auth` 프로퍼티를 직접 두고 페이로드를 `Payload`로 중첩한다 — 별도 래퍼 타입을 만들지 않는다.
  baseURL은 이 모듈 전용이 아니라 `CHALLANetwork`의 `CHALLAAPIEnvironment.baseURL`(앱 전역 서버 값)을 그대로 쓴다.
- **소셜 인증** — KakaoSDK(OIDC idToken, 카카오톡 미설치 시 계정 로그인 폴백)와
  AuthenticationServices(Apple)를 `@MainActor` 서비스로 감싸고, 사용자 취소를 `.cancelled`로 매핑.
  Task 취소도 함께 처리한다 — 콜백 기반 SDK를 감싼 continuation이 취소 후에도 매달리지 않도록
  `withTaskCancellationHandler`로 풀어주고(Apple은 시트도 닫는다), 뒤늦게 오는 SDK 콜백은 무시한다
- **토큰 저장** — `KeychainTokenStore`가 Domain의 `TokenStore`와 Network의 `TokenProvider`를
  동시에 구현해, 로그인이 저장한 토큰을 `AuthInterceptor`가 요청마다 읽어가게 연결
  (단, 이 두 접점에 **같은 인스턴스**를 꽂는 배선은 합성 루트의 책임이다)
- **토큰 갱신 · 세션 정리** — `AuthTokenRefresher`가 401 재시도 경로의 갱신을 한 번으로 묶고,
  갱신이 거절되면 키체인을 비운다. 재설치 판정용 실행 이력은 `UserDefaultsLaunchStateStore`가 들고 있다

**동시성**: Swift 6 strict concurrency 기준, `@unchecked Sendable`은
`UserDefaultsLaunchStateStore` 한 곳뿐이다 (`UserDefaults`가 `Sendable`을 채택하지 않아서 — 파일 주석 참고).
소셜 서비스는 `@MainActor` 격리하고 SDK 타입(`OAuthToken`·`ASAuthorization` 등)은 서비스 밖으로
새지 않는다 — 경계를 넘는 값은 `Sendable`인 `SocialCredential`뿐이다.
Apple 로그인의 continuation은 성공/실패 모두 `finish(with:)` 한 곳에서 정확히 1회만 resume한다.

## 공개 API

Feature가 볼 일 없는 세부 타입(Endpoint/DTO/Mapper)은 internal이고,
합성 루트가 조립에 쓰는 어댑터만 public이다:

- `struct DefaultAuthRepository: AuthRepository`
  - `init(client: any HTTPClient)` — 합성 루트가 구성한 `HTTPClient`를 주입
- `struct DefaultSocialLoginService: SocialLoginService`
  - `init()` — 카카오/애플 provider 라우팅
- `final class KeychainTokenStore: TokenStore, TokenProvider`
  - `init(keychain: any Keychain)` — 로그인 저장(`TokenStore`)과 인터셉터 조회(`TokenProvider`)의 공유 접점.
    합성 루트가 repository의 인터셉터와 `LoginUseCase.live`에 **같은 인스턴스**로 넘긴다
  - 저장 형태: access·refresh를 **키체인 항목 하나**(`challa.auth.token`)에 JSON으로 묶어 넣는다.
    두 키로 나누면 앞의 저장만 성공했을 때 *새 access + 옛 refresh* 불일치가 남아 갱신이 서버에서 거부된다.
    한 항목이면 저장·삭제가 각각 한 번의 호출이라 그 중간 상태가 생기지 않는다
  - `clear()`는 토큰 항목만 지우지 않고 **키체인 service 전체**(`Keychain.deleteAll()`)를 비운다 —
    로그아웃·탈퇴·재설치 초기화에서 인증 잔여물을 남기지 않는 쪽이 안전하고,
    나중에 인증 관련 항목이 늘어도 정리 코드를 다시 손대지 않는다
  - 오류 정책: `save`·`clear` 실패는 **그대로 전파**(정규화는 상위 UseCase 몫),
    조회 실패는 **nil로 삼킨다**(요청마다 호출되는 경로라 방어적 — 비로그인으로 간주)
- `actor AuthTokenRefresher: TokenRefreshing`(CHALLANetwork)
  - `init(refresh:tokenStore:onSessionExpired:)` — 갱신 동작 자체는 `RefreshTokenUseCase.live`를 클로저로 받고,
    이 타입은 **단일 갱신 보장 + 실패 처리**만 맡는다
  - 401을 동시에 받은 요청들이 갱신을 각자 부르면, refreshToken을 회전시키는 서버에서 두 번째가 거절되며
    살아 있는 세션이 끊긴다 — 진행 중인 갱신에 합류시켜 한 번만 부른다.
    401을 받은 요청이 실어 보낸 액세스 토큰이 이미 갱신됐다면 갱신을 건너뛰고 재시도만 허용한다
  - 실패 처리: `.network`·취소는 세션을 유지한다(오프라인에 로그아웃되지 않는다).
    그 밖의 거절은 **키체인을 비우고 `onSessionExpired`로 알린다** — 그 토큰으로는 어떤 요청도 통과하지 못한다
- `struct UserDefaultsLaunchStateStore: LaunchStateStore`
  - `init(defaults:)` — 앱 삭제와 함께 사라지는 `UserDefaults`에 실행 이력을 남겨 "설치 후 최초 실행"을 판정한다

> 조립 자체(어댑터 그래프 → `LoginUseCase.live(...)`)는 이 모듈이 아니라 합성 루트가 수행한다.
> 현재 합성 루트는 실행 앱마다 하나씩, 같은 배선을 두 벌 가진다 —
> `App/CHALLAApp/Sources/CompositionRoot.swift`(앱 시작 시 `prepareDependencies`로 1회)와
> `Auth/Login/LoginFeatureDemo/Sources/CompositionRoot.swift`(Mock 구성과 공존해야 해서 Store별 `withDependencies`).
> 어댑터 구성을 바꿀 때는 두 파일을 함께 고쳐야 한다.

## 의존성

- **이 모듈이 의존**: `AuthDomain`(인터페이스·엔티티·오류) · `CHALLANetwork`(HTTPClient·Endpoint·인터셉터) ·
  `Keychain`(Core, 보안 저장소) · `KakaoSDKCommon`/`KakaoSDKAuth`/`KakaoSDKUser`(2.28.0, Tuist/Package.swift 경유) ·
  `AuthenticationServices`/`UIKit`(시스템)
- **이 모듈에 의존**: `CHALLAApp` · `LoginFeatureDemo`(둘 다 조립 지점 — 규칙 2의 예외)

전제조건 (조립 지점 책임):
- 카카오 개발자 콘솔 OpenID Connect 활성화 (미활성 시 idToken이 없어 `.social` 오류)
- 앱 Info.plist에 Kakao URL 스킴 + `KakaoSDK.initSDK` + `onOpenURL` 처리
- Sign in with Apple 엔타이틀먼트
- 서버 값(baseURL·ATS 예외)은 `Project.makeAppProject(usesAPIEnvironment: true)`로 자동 주입 —
  개별 앱이 직접 설정할 필요 없음

## 테스트 실행 방법

```bash
mise exec -- tuist test AuthData
```

Swift Testing 기반 (`Tests/Support/` — `MockHTTPClient`·`MockKeychain`·`MockTokenStore`):

**DTO 테스트**
- `BaseResponseDTOTests` — 언랩 성공/실패(`success=false`·`data` 누락) · `ensureSuccess`

**Repository 테스트**
- `DefaultAuthRepositoryTests` — login/refresh/logout 성공 변환, `success=false`→`.server`,
  401→`.unauthorized`, 전송 실패→`.network`

**토큰 저장·갱신 테스트**
- `KeychainTokenStoreTests` — 저장·조회 라운드트립, 단일 항목 저장, `clear`의 service 전체 비우기, 실패 정책
- `AuthTokenRefresherTests` — 성공/네트워크 실패/거절(키체인 정리 + 만료 알림)/취소,
  동시 호출 시 갱신 1회, 이미 갱신된 토큰이면 갱신 생략
- `UserDefaultsLaunchStateStoreTests` — 최초 실행 판정과 기록 유지 (테스트마다 별도 suite name)

**ErrorMapping 테스트**
- `AuthErrorMappingTests` — `NetworkError` 5개 케이스 전수 매핑 테이블 (transport→.network,
  상태 코드 401→.unauthorized/기타→.server, invalidRequest/nonHTTPResponse→.unknown)

> UseCase 오케스트레이션(`LoginUseCase.live` 등)은 인터페이스만 의존하므로 테스트도 `AuthDomain`으로 옮겼다
> (`LoginUseCaseLiveTests` 등 3종 + `MockAuthRepository`/`MockSocialLoginService`/`MockTokenStore`).

소셜 서비스(Kakao/Apple)는 네이티브 UI·실기기 의존이라 유닛테스트 범위 밖 — Demo앱에서 실동작으로 검증한다.
