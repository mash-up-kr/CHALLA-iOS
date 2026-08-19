# AuthDomain

## 레이어와 책임

**Domain 레이어**. 로그인·토큰에 관한 순수 도메인 모듈이다 — 엔티티(값 타입), 인터페이스(protocol),
Feature-facing UseCase(키 + 라이브 오케스트레이션)를 정의한다. 서버·소셜 SDK·Keychain의 존재를 모르며
(import는 `Foundation` + `Dependencies`/`DependenciesMacros`뿐), 인터페이스의 구현은 전부 `AuthData`가 맡는다
(아키텍처 규칙 1: `Feature → Domain ← Data`).

**의존 주입 설계**: UseCase는 `@DependencyClient` + `TestDependencyKey`로 선언하고 **`liveValue`를
의도적으로 두지 않는다**. 인자 없는 `liveValue`를 채우려면 구체 어댑터(`DefaultAuthRepository`·Keychain 등)를
생성해야 하고, 그러려면 Data를 import해야 해 규칙 2(Feature는 Data를 모른다)가 깨지기 때문이다.
반면 **오케스트레이션 로직 자체는 이 Domain 모듈에 둔다** — `LoginUseCase.live(social:repository:tokenStore:)`가
의존성을 **인터페이스로만** 받아 소셜→서버→저장 순서를 조립한다(구체 타입 무의존).
`.live(...)`는 `testValue`·`previewValue`와 같은 `TestDependencyKey` extension에 둔다 — 셋 다 "이 유스케이스를 얻는 방법"이다.
`AuthData`의 public 어댑터를 만들어 이 팩토리에 넘기고 주입하는 일만 합성 루트
(`CHALLAApp`·`LoginFeatureDemo`의 `CompositionRoot`)가 `prepareDependencies`/`withDependencies`로 담당한다.
주입 없이 라이브에서 접근하면 "no live implementation" 리포트가 뜨는데, 이는 버그가 아니라
조립 지점 주입을 강제하는 의도된 설계다.

**동시성**: 모든 공개 타입은 값 타입 + `Sendable`이다 (`@unchecked` 미사용).
Swift 6 strict concurrency(`complete`)에서 경고 없이 컴파일되며, `@Dependency` 경계를 넘어도 안전하다.

## 공개 API

폴더는 한 종류만 담는다 — `Entities/`는 엔티티, `Interface/`는 protocol,
`Models/`는 특정 경계 전용 입출력 구조, `UseCases/`는 유스케이스.

### Entities (`Sources/Entities/`)
여러 유스케이스·인터페이스가 공유하는 핵심 업무 데이터. 외부(SDK·서버)가 바뀌어도 흔들리지 않는 것만 둔다.

- `enum AuthProvider` — `.kakao` / `.apple` (서버 문자열 매핑은 AuthData DTO의 책임)
- `struct AuthToken` — `accessToken` · `refreshToken` (3개 유스케이스 + `TokenStore`가 공유, Keychain에 영속)

### Errors
- `enum AuthError` — `.cancelled` · `.network` · `.unauthorized` · `.server(message:)` · `.social(reason:)` · `.unknown`
  - `userMessage` — 얼럿용 최소 문구 (`.cancelled`는 빈 문자열 = 표시 안 함)

### Interface (`Sources/Interface/` — 구현: AuthData)
protocol만 둔다. 경계에서 오가는 데이터 구조는 `Models/` 소속이다.

- `protocol AuthRepository` — `login(_:)` · `refresh(refreshToken:)` · `logout(refreshToken:)`
- `protocol SocialLoginService` — `authenticate(_:)`
- `protocol TokenStore` — `save(_:)` · `loadAccessToken()` · `loadRefreshToken()` · `clear()`
- `protocol LaunchStateStore` — `hasLaunchedBefore` · `markLaunched()`.
  키체인은 앱을 삭제해도 남을 수 있어서, 앱과 함께 사라지는 저장소의 플래그와 대조해 재설치를 판정한다

### Models (`Sources/Models/`)
경계 하나만을 위한 입출력 구조. 엔티티가 아니므로 `Entities/`와 섞지 않는다.

- `struct SocialCredential` — `provider` · `idToken` · `authorizationCode?`
  (`SocialLoginService` 출력 → `AuthRepository` 입력. 필드가 각 소셜 SDK 응답 모양에 종속돼 엔티티가 아니다)
- `struct AuthSession` — `token` + `isNewUser` (`AuthRepository.login`이 돌려주는 인증 세션 — 토큰 포함, 저장 전 단계까지만)
- `struct LoginResult` — `isNewUser` (`LoginUseCase.run`이 돌려주는 로그인 결과 — Feature 노출용, 토큰 감춤)
- `enum SessionRestoration` — `.restored` / `.signedOut` (`RestoreSessionUseCase.run`의 판정 결과)

### Session (`Sources/Session/`)
- `final class SessionExpirationChannel` — 토큰 갱신이 최종 실패했음을(재로그인 필요) 앱 루트로 흘리는 단방향 채널.
  `events`(최신 1건만 버퍼링) · `notify()` · `finish()`.
  갱신은 요청 재시도 경로 깊은 곳에서 일어나 호출 스택으로는 화면까지 오류가 올라오지 않기 때문에 필요하다.
  어느 화면으로 보낼지는 받는 쪽(App)이 정한다

### UseCases (`@DependencyClient` — liveValue 없음, 라이브 팩토리는 `.live(...)`)
- `LoginUseCase` (`\.loginUseCase`) — 소셜 인증 → 서버 로그인 → 토큰 저장을 한 번에, `LoginResult` 반환
  - `static func live(social:repository:tokenStore:) -> LoginUseCase` — 의존성을 인터페이스로 받는 라이브 조립
- `RefreshTokenUseCase` (`\.refreshTokenUseCase`) — 토큰 갱신 (저장된 refreshToken으로 토큰 쌍 갱신)
  - `static func live(repository:tokenStore:) -> RefreshTokenUseCase`
- `LogoutUseCase` (`\.logoutUseCase`) — 로그아웃 (서버 로그아웃 + 저장 토큰 삭제)
  - `static func live(repository:tokenStore:) -> LogoutUseCase`
  - 서버 실패 처리 정책: `.network`만 전파해 토큰을 남기고(재시도 가능), 그 밖의 거절(`.unauthorized`·`.server` 등)은
    삼키고 로컬을 정리한다. 서버가 이미 무효로 본 세션 때문에 로컬 토큰이 남으면 영구히 로그아웃할 수 없다
- `RestoreSessionUseCase` (`\.restoreSessionUseCase`) — 앱 시작 시 자동 로그인 가능 여부 판정.
  설치 후 최초 실행이면 이전 설치가 남긴 키체인을 지우고 `.signedOut`을 돌려준다
  - `static func live(tokenStore:launchState:) -> RestoreSessionUseCase`
  - **앱 시작 직후, 어떤 인증 요청보다 먼저 한 번** 실행되는 것을 전제로 한다 (호출 지점은 `AppFeature.task`)

## 의존성

- **이 모듈이 의존**: `Dependencies` · `DependenciesMacros` (swift-dependencies — TCA 전이 의존, `Tuist/Package.swift` 경유)
- **이 모듈에 의존**: `LoginFeature`(UseCase 키를 `@Dependency`로 주입받아 사용) · `AuthData`(인터페이스 구현 + `.live(...)`에 넘길 구체 어댑터 조립)

## 테스트 실행 방법

```bash
mise exec -- tuist test AuthDomain
```

Swift Testing 기반 (시뮬레이터 불필요한 순수 유닛테스트). Mock 4종(`Tests/Support/` —
`MockAuthRepository`·`MockSocialLoginService`·`MockTokenStore`·`MockLaunchStateStore`)으로
인터페이스만 갈아끼워 검증한다:
- `AuthErrorTests` — `userMessage` 각 케이스(`.cancelled`는 빈 문자열, 빈 메시지 대체 문구 포함) · 동등성
- `DomainModelTests` — 값 타입 동등성 · 프로퍼티 보관 (중첩 스위트가 `Sources/`의 폴더 분류를 따른다: 엔티티 / 경계 모델)
- `LoginUseCaseLiveTests` — `.live` 성공 흐름(소셜→서버→저장), 소셜 취소 전파, 저장 실패→`.unknown`
- `LogoutUseCaseLiveTests` — 저장 토큰 유무별 서버 호출/로컬 정리, 네트워크 오류 시 토큰 유지,
  서버 거절 시에도 로컬 정리, clear 실패→`.unknown`
- `RefreshTokenUseCaseLiveTests` — 저장 토큰 없을 시 `.unauthorized`, 성공 시 새 토큰 저장·반환, 실패 시 기존 토큰 유지
- `RestoreSessionUseCaseLiveTests` — 토큰 유무별 판정, 최초 실행 시 키체인 초기화(한 번만), 삭제 실패에도 진행

`AuthError(networkError:)` 매핑과 `DefaultAuthRepository`의 서버 응답 언랩은 `AuthData` 소속이므로 여기서 테스트하지 않는다.
