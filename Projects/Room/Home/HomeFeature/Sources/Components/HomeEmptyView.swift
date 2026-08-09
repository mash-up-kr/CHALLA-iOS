import CHALLADesignSystem
import SwiftUI

/// 방이 하나도 없을 때의 홈. 인사말과 프로필을 가운데 두고 아래에 진입 버튼 둘을 놓는다.
///
/// 리듀서를 직접 알지 않고 값과 동작만 받는다 — 프리뷰에서 스토어 없이 띄우기 위해서다.
struct HomeEmptyView: View {

    // MARK: - 프로퍼티

    let nickname: String
    let profileImageURL: URL?
    let onCreateRoom: () -> Void
    let onJoinRoom: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            greeting
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            actions
        }
    }

    // MARK: - 인사말

    private var greeting: some View {
        VStack(spacing: 0) {
            // 두 줄을 각각 Text로 두는 것은 줄마다 색이 달라서다. challaFont가 줄 높이만큼
            // 위아래 여백을 더하므로 VStack 간격 0이 시안의 줄 간격(30 - 22)과 같아진다.
            VStack(spacing: 0) {
                Text(nickname)
                    .challaFont(.heading.small.bold)
                    .foregroundStyle(CHALLAColor.Primary.yellow)
                Text("행복한 찰나를 남겨 보세요")
                    .challaFont(.heading.small.bold)
                    .foregroundStyle(CHALLAColor.Label.normal)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, EmptyMetric.greetingHorizontalPadding)
            .padding(.vertical, EmptyMetric.greetingVerticalPadding)

            CHALLAAsyncImage(url: profileImageURL) { image in
                CHALLAAvatar(photo: image, size: EmptyMetric.avatarSize)
            } placeholder: {
                CHALLAAvatar(photo: nil, size: EmptyMetric.avatarSize)
            }
        }
    }

    // MARK: - 진입 버튼

    private var actions: some View {
        VStack(spacing: EmptyMetric.buttonSpacing) {
            CHALLATextButton("방 만들기", variant: .theme, isFullWidth: true, action: onCreateRoom)
            CHALLATextButton("초대 코드로 입장하기", isFullWidth: true, action: onJoinRoom)
        }
        .padding(.horizontal, EmptyMetric.horizontalPadding)
        .padding(.top, EmptyMetric.actionsTopPadding)
    }
}

// MARK: - Figma 실측값

private enum EmptyMetric {
    /// 인사말 좌우 여백.
    static let greetingHorizontalPadding: CGFloat = 16
    /// 인사말 위아래 여백. challaFont가 글자 상자에 더하는 여백을 빼야 시안대로 보인다.
    static let greetingVerticalPadding: CGFloat = 24 - CHALLATypography.heading.small.bold.lineBoxInset
    /// 프로필 사진 지름.
    static let avatarSize: CGFloat = 80
    /// 버튼 영역 좌우 여백.
    static let horizontalPadding: CGFloat = 16
    /// 버튼 영역 위 여백.
    static let actionsTopPadding: CGFloat = 8
    /// 버튼 사이 간격.
    static let buttonSpacing: CGFloat = 8
}

// MARK: - Preview

#Preview("사진 없음") {
    HomeEmptyView(
        nickname: "나는야멋쟁이토마토",
        profileImageURL: nil,
        onCreateRoom: {},
        onJoinRoom: {}
    )
    .challaMainBackground()
}

#Preview("사진 있음") {
    HomeEmptyView(
        nickname: "나는야멋쟁이토마토",
        profileImageURL: URL(string: "https://picsum.photos/seed/profile/160"),
        onCreateRoom: {},
        onJoinRoom: {}
    )
    .challaMainBackground()
}
