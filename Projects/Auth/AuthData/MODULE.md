# AuthData

## 레이어와 책임

**Data 레이어**. `AuthDomain`의 인터페이스 3개(`AuthRepository`·`SocialLoginService`·`TokenStore`)를 구현한
**구체 어댑터**를 public으로 제공한다 (아키텍처 규칙 1: `Feature → Domain ← Data`).
이 모듈은 **구현체만 내놓고, 조립·주입은 하지 않는다** — 어댑터를 모아 `LoginUseCase.live(...)`로 완성하는
합성 루트는 상위(현재 Demo앱 / 추후 App·DIContainer)에 있다. 오케스트레이션(소셜→서버→저장 순서)도 Domain 소유다.

담당 범위:
- **서버 통신** — `AuthEndpoint`(login/refresh/logout, POST) + 공통 응답 래퍼 `BaseResponseDTO` 언랩 +
  `NetworkError`와 서버 실패 응답(`success=false`)을 `AuthError`로 정규화 (`DefaultAuthRepository`).
  baseURL은 이 모듈 전용이 아니라 `CHALLANetwork`의 `CHALLAAPIEnvironment.baseURL`(앱 전역 서버 값)을 그대로 쓴다.
- **소셜 인증** — KakaoSDK(OIDC idToken, 카카오톡 미설치 시 계정 로그인 폴백)와
  AuthenticationServices(Apple)를 `@MainActor` 서비스로 감싸고, 사용자 취소를 `.cancelled`로 매핑
- **토큰 저장** — `KeychainTokenStore`가 Domain의 `TokenStore`와 Network의 `TokenProvider`를
  동시에 구현해, 로그인이 저장한 토큰을 `AuthInterceptor`가 요청마다 읽어가게 연결
  (단, 이 두 접점에 **같은 인스턴스**를 꽂는 배선은 합성 루트의 책임이다)

**동시성**: Swift 6 strict concurrency 기준, `@unchecked Sendable` 미사용.
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
  - 오류 정책: `save`·`clear` 실패는 **그대로 전파**(정규화는 상위 UseCase 몫),
    조회 실패는 **nil로 삼킨다**(요청마다 호출되는 경로라 방어적 — 비로그인으로 간주)

> 조립 자체(어댑터 그래프 → `LoginUseCase.live(...)`)는 이 모듈이 아니라 합성 루트가 수행한다.
> 현재 조립 코드는 `LoginFeatureDemo`의 `CompositionRoot`에 임시로 있고, App·DIContainer 도입 시
> `DIContainer/LiveDependency`로 이관된다 (해당 파일들의 `TODO: [App/DIContainer 도입 시 이관]` 참고).

## 의존성

- **이 모듈이 의존**: `AuthDomain`(인터페이스·엔티티·오류) · `CHALLANetwork`(HTTPClient·Endpoint·인터셉터) ·
  `Keychain`(Core, 보안 저장소) · `KakaoSDKCommon`/`KakaoSDKAuth`/`KakaoSDKUser`(2.28.0, Tuist/Package.swift 경유) ·
  `AuthenticationServices`/`UIKit`(시스템)
- **이 모듈에 의존**: `LoginFeatureDemo`(조립 지점 — 규칙 2의 유일한 예외) · 추후 DIContainer

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

Swift Testing 기반 (`MockHTTPClient` 한 종 — Repository/매핑 검증용):

**DTO 테스트**
- `BaseResponseDTOTests` — 언랩 성공/실패(`success=false`·`data` 누락) · `ensureSuccess`

**Repository 테스트**
- `DefaultAuthRepositoryTests` — login/refresh/logout 성공 변환, `success=false`→`.server`,
  401→`.unauthorized`, 전송 실패→`.network`

**ErrorMapping 테스트**
- `AuthErrorMappingTests` — `NetworkError` 5개 케이스 전수 매핑 테이블 (transport→.network,
  상태 코드 401→.unauthorized/기타→.server, invalidRequest/nonHTTPResponse→.unknown)

> UseCase 오케스트레이션(`LoginUseCase.live` 등)은 인터페이스만 의존하므로 테스트도 `AuthDomain`으로 옮겼다
> (`LoginUseCaseLiveTests` 등 3종 + `MockAuthRepository`/`MockSocialLoginService`/`MockTokenStore`).

소셜 서비스(Kakao/Apple)는 네이티브 UI·실기기 의존이라 유닛테스트 범위 밖 — Demo앱에서 실동작으로 검증한다.
