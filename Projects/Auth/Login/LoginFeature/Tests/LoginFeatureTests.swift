import AuthDomain
import ComposableArchitecture
import LoginFeature
import Testing

@MainActor
@Suite("LoginFeature")
struct LoginFeatureTests {

    /// `LoginUseCase` 하나만 override하면 되는 Feature라 makeStore 헬퍼도 그만큼 얇다.
    /// (testValue는 unimplemented — override 없이 호출되면 테스트가 실패를 리포트한다.)
    private func makeStore(loginUseCase: LoginUseCase) -> TestStoreOf<LoginFeature> {
        TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        } withDependencies: {
            $0.loginUseCase = loginUseCase
        }
    }

    @Test("온보딩 페이저 스와이프 → onboardingPage 갱신")
    func onboardingPageChanged() async {
        // 로그인 이펙트를 타지 않는 액션이라 useCase override 없이 testValue(unimplemented) 그대로 둔다.
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        }

        await store.send(.view(.onboardingPageChanged(2))) {
            $0.onboardingPage = 2
        }
        await store.send(.view(.onboardingPageChanged(0))) {
            $0.onboardingPage = 0
        }
    }

    @Test("카카오 탭 → 로딩 → 성공 → delegate.loginSucceeded 전달")
    func kakaoLoginSuccess() async {
        let store = makeStore(
            loginUseCase: LoginUseCase(run: { provider in
                #expect(provider == .kakao) // 탭된 provider가 useCase까지 그대로 전달되는지
                return LoginResult(isNewUser: true)
            })
        )

        await store.send(.view(.kakaoLoginButtonTapped)) {
            $0.inFlightProvider = .kakao
        }
        #expect(store.state.isLoading)

        await store.receive(\.loginResponse.success) {
            $0.inFlightProvider = nil
        }
        await store.receive(\.delegate.loginSucceeded)
        #expect(store.state.isLoading == false)
    }

    @Test("애플 탭도 동일 흐름 — delegate.loginSucceeded 전달")
    func appleLoginSuccess() async {
        let store = makeStore(
            loginUseCase: LoginUseCase(run: { provider in
                #expect(provider == .apple)
                return LoginResult(isNewUser: false)
            })
        )

        await store.send(.view(.appleLoginButtonTapped)) {
            $0.inFlightProvider = .apple
        }
        await store.receive(\.loginResponse.success) {
            $0.inFlightProvider = nil
        }
        await store.receive(\.delegate.loginSucceeded)
    }

    @Test("실패(.server) → 로딩 해제 + '로그인 실패' 얼럿(userMessage 본문)")
    func serverFailureShowsAlert() async {
        let store = makeStore(
            loginUseCase: LoginUseCase(run: { _ in
                throw AuthError.server(message: "점검 중이에요.")
            })
        )

        await store.send(.view(.kakaoLoginButtonTapped)) {
            $0.inFlightProvider = .kakao
        }
        await store.receive(\.loginResponse.failure) {
            $0.inFlightProvider = nil
            $0.alert = AlertState {
                TextState("로그인 실패")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState("점검 중이에요.")
            }
        }

        // 확인(닫기) → 얼럿 해제. delegate가 없었음은 전체 수신 검사(exhaustivity)가 보장한다.
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }

    @Test("취소(.cancelled) → 얼럿 없이 inFlightProvider만 해제")
    func cancelledIsSilentlyIgnored() async {
        let store = makeStore(
            loginUseCase: LoginUseCase(run: { _ in
                throw AuthError.cancelled
            })
        )

        await store.send(.view(.appleLoginButtonTapped)) {
            $0.inFlightProvider = .apple
        }
        await store.receive(\.loginResponse.failure) {
            $0.inFlightProvider = nil
        }
        #expect(store.state.alert == nil)
    }

    @Test("로딩 중 중복 탭(같은/다른 버튼)은 무시된다")
    func duplicateTapsIgnoredWhileLoading() async {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        let callCount = LockIsolated(0)
        let store = makeStore(
            loginUseCase: LoginUseCase(run: { _ in
                callCount.withValue { $0 += 1 }
                for await _ in stream {
                    break
                } // 완료를 보류시켜 "로딩 중" 유지
                return LoginResult(isNewUser: false)
            })
        )

        await store.send(.view(.kakaoLoginButtonTapped)) {
            $0.inFlightProvider = .kakao
        }
        // 로딩 중 재탭 — 상태 변화도, 새 이펙트도 없어야 한다 (클로저 생략 = 무변화 단언).
        await store.send(.view(.kakaoLoginButtonTapped))
        await store.send(.view(.appleLoginButtonTapped))

        continuation.yield() // 보류 중이던 첫 요청 완료
        await store.receive(\.loginResponse.success) {
            $0.inFlightProvider = nil
        }
        await store.receive(\.delegate.loginSucceeded)
        #expect(callCount.value == 1)
    }

    @Test("실패로 유휴 상태에 복귀한 뒤 재시도 탭은 다시 로그인을 시작한다")
    func retryAfterFailureStartsLoginAgain() async {
        let callCount = LockIsolated(0)
        let store = makeStore(
            loginUseCase: LoginUseCase(run: { _ in
                callCount.withValue { $0 += 1 }
                if callCount.value == 1 {
                    throw AuthError.cancelled
                } // 1차: 취소로 실패
                return LoginResult(isNewUser: false) // 2차: 성공
            })
        )

        // 1차 시도 — 취소 실패로 inFlightProvider == nil(유휴) 복귀
        await store.send(.view(.kakaoLoginButtonTapped)) {
            $0.inFlightProvider = .kakao
        }
        await store.receive(\.loginResponse.failure) {
            $0.inFlightProvider = nil
        }

        // 재시도 — 중복 탭 가드의 반대 방향: 유휴 상태에서는 탭이 다시 통과해야 한다
        await store.send(.view(.kakaoLoginButtonTapped)) {
            $0.inFlightProvider = .kakao
        }
        await store.receive(\.loginResponse.success) {
            $0.inFlightProvider = nil
        }
        await store.receive(\.delegate.loginSucceeded)
        #expect(callCount.value == 2)
    }

    @Test("AuthError도 취소도 아닌 임의 오류는 .unknown으로 정규화되어 얼럿을 띄운다")
    func arbitraryErrorBecomesUnknown() async {
        struct UnexpectedError: Error {} // useCase 계약(AuthError 정규화) 밖의 임의 오류
        let store = makeStore(
            loginUseCase: LoginUseCase(run: { _ in throw UnexpectedError() })
        )

        await store.send(.view(.appleLoginButtonTapped)) {
            $0.inFlightProvider = .apple
        }
        await store.receive(\.loginResponse.failure, .unknown) {
            $0.inFlightProvider = nil
            $0.alert = AlertState {
                TextState("로그인 실패")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState("알 수 없는 오류가 발생했어요.") // AuthError.unknown.userMessage
            }
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }
}
