# LoginFeature

## 레이어와 책임

**Feature 레이어**. 로그인 화면의 TCA Feature 모듈이다 — 카카오/애플 버튼 탭을 받아
`LoginUseCase` 하나로 로그인 전 과정(소셜 인증 → 서버 로그인 → 토큰 저장)을 실행하고,
로딩(`inFlightProvider`)·실패 얼럿 상태를 관리한다. 소셜 SDK·서버·Keychain의 존재를 모르며
(`AuthData` import 없음 — 아키텍처 규칙 2), 라이브 `LoginUseCase`는 실행 앱의 `CompositionRoot`가 주입한다 —
`CHALLAApp`은 시작 시 `prepareDependencies`로 1회, `LoginFeatureDemo`는 Mock 구성과 공존해야 해서
Store별 `withDependencies`로.

로그인 성공 후 화면 분기는 이 모듈이 하지 않는다 — `delegate` 액션으로 parent(App)에 위임한다
(규칙 3: Feature 간 직접 참조 금지, 네비게이션은 App이 조립).

**프레임워크 타입**: `.staticFramework`로 선언한다. 동적 dylib으로 만들 경우 정적인 `AuthDomain`·`Dependencies`가
이 framework과 앱 바이너리(AuthData 경유)에 각각 복제 링크되어, TCA `@TaskLocal` 기반 `@Dependency` 주입이
리소스 간에 갈라질 수 있기 때문이다. 리소스(소셜 아이콘)는 Tuist가 합성하는 리소스 번들 + `Bundle.module`로 동작한다.

## 공개 API

### `LoginFeature` (@Reducer)
- `State` — `inFlightProvider: AuthProvider?` (진행 중 provider, `nil`=유휴) ·
  `alert: AlertState?`(@Presents) · `isLoading`(계산 — 두 버튼 비활성화 근거)
- `Action` (taxonomy)
  - `view(View)` — `kakaoLoginButtonTapped` · `appleLoginButtonTapped` (UI 전용, `@ViewAction`용)
  - `delegate(Delegate)` — parent(App)와의 유일한 통신 채널
  - `loginResponse(Result<LoginResult, AuthError>)` — 내부 비동기 결과
  - `alert(PresentationAction<Alert>)` — 확인 버튼만 있는 얼럿 (`Alert`는 빈 enum)

### Delegate 계약 (parent가 수신)
- `loginSucceeded` — 로그인 완료. 다음 화면은 App이 내 프로필을 다시 조회해 정한다
  (닉네임 유무가 기준이라 로그인 응답의 `isNew`는 싣지 않는다 — 프로필 설정을 이탈한 사용자를 다음 실행에서도 다시 잡아야 한다)

### 동작 규칙
- 로딩 중 중복 탭 무시 (`inFlightProvider` 가드 + `CancelID.login`/`cancelInFlight` 방어)
- `AuthError.cancelled`(사용자 취소)는 얼럿 없이 조용히 종료
- 그 외 실패는 "로그인 실패" 제목 + `AuthError.userMessage` 본문 + "확인" 버튼 얼럿

### `LoginView` (SwiftUI, `@ViewAction(for: LoginFeature.self)`)
- `init(store: StoreOf<LoginFeature>)` — App/Demo가 Store를 만들어 주입한다
- 구성: 배경(`Background.surface`) → 중앙 `LoginBrandView`(opacity 0.1 장식 — VoiceOver 제외)
  → 하단 소셜 버튼 스택(카카오/애플) + 실패 얼럿 바인딩(`$store.scope(state: \.alert, ...)`)
- 로딩 UX: 탭한 버튼만 스피너(`inFlightProvider`), 두 버튼 모두 비활성(`isLoading`)
- VoiceOver: 브랜드 그룹은 `.accessibilityHidden(true)`로 제외, 소셜 버튼은 아이콘·스피너를
  합쳐 버튼 하나로 읽는다 (label=타이틀, value=진행 상태 "로그인 중")
- 색·타이포는 DS 토큰만 사용 (`CHALLAColor.Social.*`, `CHALLAFont.*` — 원시 hex/Font.custom 없음)
- 하위 컴포넌트 `LoginBrandView`·`SocialLoginButton`은 internal (모듈 밖 비공개)

## 의존성

- **이 모듈이 의존**: `AuthDomain`(엔티티·`AuthError`·`\.loginUseCase` 키) ·
  `ComposableArchitecture`(TCA 1.26) · `CHALLADesignSystem`(색·타이포 토큰)
- **이 모듈에 의존**: `CHALLAApp`(live 주입) ·
  `LoginFeatureDemo`(live는 자기 `CompositionRoot`, Mock은 `DemoRootView`가 인라인 스텁으로 주입)

## 테스트 실행 방법

```bash
mise exec -- tuist test LoginFeature
```

TCA `TestStore` 기반 Swift Testing — `LoginFeatureTests` (7개):
- 카카오/애플 탭 → 로딩 → 성공 → `delegate.loginSucceeded` 전달
- 실패(`.server`) → "로그인 실패" 얼럿 세팅 → 확인으로 해제
- 취소(`.cancelled`) → 얼럿 없이 `inFlightProvider`만 해제
- 로딩 중 중복 탭(같은/다른 버튼) 무시 — useCase 1회 호출 보장
- 실패 후 유휴 복귀 시 재시도 탭으로 다시 로그인 시작 (재탭 가능성)
- AuthError 밖의 임의 오류(내부 계약 위반) → `.unknown`으로 정규화 후 얼럿 표시
