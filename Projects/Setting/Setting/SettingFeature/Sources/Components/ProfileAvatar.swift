import CHALLADesignSystem
import SwiftUI

/// 원형 프로필 이미지. 사진이 없으면 기본 아바타를 표시한다.
///
/// 설정 메인 헤더(`SettingProfileHeader`)와 계정 관리 요약(`AccountProfileSummary`)이
/// 같은 그림을 쓴다. 시안에서도 두 화면의 아바타는 픽셀 단위로 동일하다.
///
/// 크기를 파라미터로 열지 않는다 — 쓰는 곳 둘 다 68이고, 실루엣 아이콘 크기가 원 지름과
/// 함께 움직여야 해서 지름만 바꿀 수 있게 열면 비율이 깨진다.
struct ProfileAvatar: View {

    let url: URL?

    /// 아바타 지름. 호출부가 줄 높이를 맞출 때 참조한다.
    ///
    /// `nonisolated` — `View` 준수로 타입 멤버가 메인 액터에 묶이는데,
    /// 이 값은 호출부의 (액터와 무관한) `Metric` 상수 계산에 쓰인다.
    nonisolated static let size: CGFloat = 68

    var body: some View {
        CHALLAAsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            // 미설정·로딩·실패 상태는 동일한 기본 아바타를 사용한다.
            defaultAvatar
        }
        .frame(width: Self.size, height: Self.size)
        .clipShape(Circle())
        // 인접한 닉네임과 VoiceOver 낭독이 중복되지 않도록 제외한다.
        .accessibilityHidden(true)
    }

    private var defaultAvatar: some View {
        Circle()
            .fill(Metric.background)
            .overlay {
                CHALLAIcon.profile.image(
                    size: Metric.silhouetteSize,
                    color: Metric.silhouette
                )
            }
    }
}

// MARK: - Metric

private enum Metric {

    static let silhouetteSize = CHALLAIcon.Size.size32

    /// 기본 아바타 색 — 시안 실측 `#242424` 원 + `#3B3B3B` 실루엣이 각각 토큰과 일치한다.
    static let background = CHALLAColor.Background.level2
    static let silhouette = CHALLAColor.Background.level4
}

#Preview {
    VStack(spacing: 16) {
        ProfileAvatar(url: URL(string: "https://picsum.photos/seed/challa-profile/200"))
        ProfileAvatar(url: nil)
    }
    .padding()
    .background(CHALLAColor.Background.surface)
}
