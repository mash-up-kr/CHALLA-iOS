import CHALLADesignSystem
import SwiftUI

/// 프로필 기본 아바타 — 회색 원 + 실루엣.
///
/// 설정 메인 헤더(`SettingProfileHeader`)와 계정 관리 요약(`AccountProfileSummary`)이
/// 같은 그림을 쓴다. 시안에서도 두 화면의 아바타는 픽셀 단위로 동일하다.
///
/// **프로필 사진은 아직 그리지 않는다.** `SettingProfile.avatarURL`이 있어도 항상 기본 아바타다 —
/// 이미지 로딩 모듈(#25 `CHALLAImageKit`)이 들어온 뒤 여기에 연결한다.
/// 그래서 지금은 받는 값이 없다.
///
/// 크기를 파라미터로 열지 않는다 — 쓰는 곳 둘 다 68이고, 실루엣 아이콘 크기가 원 지름과
/// 함께 움직여야 해서 지름만 바꿀 수 있게 열면 비율이 깨진다.
struct ProfileAvatar: View {

    /// 아바타 지름. 호출부가 줄 높이를 맞출 때 참조한다.
    ///
    /// `nonisolated` — `View` 준수로 타입 멤버가 메인 액터에 묶이는데,
    /// 이 값은 호출부의 (액터와 무관한) `Metric` 상수 계산에 쓰인다.
    nonisolated static let size: CGFloat = 68

    var body: some View {
        Circle()
            .fill(Metric.background)
            .frame(width: Self.size, height: Self.size)
            .overlay {
                CHALLAIcon.profile.image(
                    size: Metric.silhouetteSize,
                    color: Metric.silhouette
                )
            }
            // 닉네임이 바로 옆(또는 아래)에서 읽히므로 중복 낭독을 막는다.
            .accessibilityHidden(true)
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
    ProfileAvatar()
        .padding()
        .background(CHALLAColor.Background.surface)
}
