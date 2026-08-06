import CHALLADesignSystem
import SwiftUI

/// 카카오/애플 공용 소셜 로그인 버튼.
///
/// 로딩 중이면 콘텐츠(아이콘 + 타이틀)를 숨기고 같은 자리에 스피너를 띄운다 —
/// ZStack + opacity로 자리를 유지해 버튼 크기가 흔들리지 않는다.
/// 로딩/비활성 판단은 리듀서 상태(`inFlightProvider`)에서 내려온다 (뷰는 표시만).
struct SocialLoginButton: View {

    let title: String
    let icon: Image
    let background: Color
    let foreground: Color
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: 4) {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)

                    Text(title)
                        .challaFont(.body.large.bold)
                }
                .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .tint(foreground)
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isDisabled)
        .accessibilityElement(children: .ignore) // 아이콘·스피너는 장식 — 버튼 하나로 읽는다
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityStatus)
    }

    // TODO: 임의 작성 문구 — 접근성 문구 정책 확정 시 교체할 것.
    private var accessibilityStatus: String {
        isLoading ? "로그인 중" : ""
    }
}

// MARK: - Preview

#Preview("유휴 / 로딩 / 비활성") {
    ZStack {
        CHALLAColor.Background.surface.ignoresSafeArea()

        VStack(spacing: 8) {
            SocialLoginButton(
                title: "카카오로 시작하기",
                icon: Image("kakaoIcon", bundle: .module),
                background: CHALLAColor.Social.kakao,
                foreground: CHALLAColor.Social.kakaoLabel,
                isLoading: false,
                isDisabled: false
            ) {}

            SocialLoginButton(
                title: "카카오로 시작하기",
                icon: Image("kakaoIcon", bundle: .module),
                background: CHALLAColor.Social.kakao,
                foreground: CHALLAColor.Social.kakaoLabel,
                isLoading: true,
                isDisabled: true
            ) {}

            SocialLoginButton(
                title: "Apple로 시작하기",
                icon: Image("appleIcon", bundle: .module),
                background: CHALLAColor.Social.apple,
                foreground: CHALLAColor.Social.appleLabel,
                isLoading: false,
                isDisabled: true
            ) {}
        }
        .padding(.horizontal, 16)
    }
}
