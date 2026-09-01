import AuthDomain
import CHALLADesignSystem
import ComposableArchitecture
import SwiftUI

/// 로그인 화면 (Figma onboarding1~5).
///
/// 배경 위에 상단 온보딩 페이저 → 하단 소셜 로그인 버튼 스택 순의 세로 흐름.
/// 뷰는 상태 렌더링과 `send(...)` 전달만 한다 — 로딩 가드·에러 분기는 전부
/// `LoginFeature` 리듀서 책임이다 (뷰에 비즈니스 로직 없음).
@ViewAction(for: LoginFeature.self)
public struct LoginView: View {

    @Bindable public var store: StoreOf<LoginFeature>

    public init(store: StoreOf<LoginFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            CHALLAColor.Background.surface
                .ignoresSafeArea()

            // 버튼이 페이저와 같은 세로 흐름에 있어야 작은 기기에서 페이저가 버튼 위 공간만큼만 차지한다
            VStack(spacing: 0) {
                LoginOnboardingPagerView(
                    currentPage: $store.onboardingPage.sending(\.view.onboardingPageChanged)
                )

                bottomButtons
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    /// 하단 고정 소셜 로그인 버튼 스택.
    /// 하단은 홈 인디케이터 세이프에어리어를 그대로 존중한다 (추가 bottom 패딩 없음).
    private var bottomButtons: some View {
        VStack(spacing: 8) {
            SocialLoginButton(
                title: "카카오로 시작하기",
                icon: Image("kakaoIcon", bundle: .module),
                background: CHALLAColor.Social.kakao,
                foreground: CHALLAColor.Social.kakaoLabel,
                isLoading: store.inFlightProvider == .kakao,
                isDisabled: store.isLoading
            ) {
                send(.kakaoLoginButtonTapped)
            }

            SocialLoginButton(
                title: "Apple로 시작하기",
                icon: Image("appleIcon", bundle: .module),
                background: CHALLAColor.Social.apple,
                foreground: CHALLAColor.Social.appleLabel,
                isLoading: store.inFlightProvider == .apple,
                isDisabled: store.isLoading
            ) {
                send(.appleLoginButtonTapped)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview("유휴") {
    // 프리뷰 컨텍스트에서는 LoginUseCase.previewValue(즉시 성공 목)가 자동 적용된다.
    LoginView(
        store: Store(initialState: LoginFeature.State()) {
            LoginFeature()
        }
    )
}

#Preview("로딩 — 버튼 탭 후 1.5초") {
    // previewValue는 즉시 반환이라 스피너가 보이지 않으므로, 지연 목을 주입해
    // 탭한 버튼의 스피너 + 두 버튼 비활성화를 눈으로 확인한다.
    LoginView(
        store: Store(initialState: LoginFeature.State()) {
            LoginFeature()
        } withDependencies: {
            $0.loginUseCase = LoginUseCase(run: { _ in
                try await Task.sleep(for: .seconds(1.5))
                return LoginResult(isNewUser: true)
            })
        }
    )
}
