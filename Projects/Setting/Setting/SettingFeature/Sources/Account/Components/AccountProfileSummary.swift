import CHALLADesignSystem
import SettingDomain
import SwiftUI

/// 계정 관리 화면 맨 위의 프로필 요약 — 아바타 + 닉네임을 가운데 정렬로 쌓는다.
///
/// 설정 메인의 `SettingProfileHeader`와 값은 같지만 배치가 다르다(가로 → 세로, 편집 버튼 없음).
/// 하나로 합치면 두 배치를 가르는 분기가 생겨서 각자 두고 아바타만 공유한다(`ProfileAvatar`).
struct AccountProfileSummary: View {

    /// `nil`이면 아직 불러오는 중 — 자리만 잡아 화면이 덜컥거리지 않게 한다.
    let profile: SettingProfile?

    var body: some View {
        VStack(spacing: 0) {
            ProfileAvatar()
            nickname
                .padding(.top, Metric.avatarToTextSpacing)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 닉네임

    /// 시안에는 닉네임 아래 이메일 줄이 있지만 서버가 이메일을 내려주지 않아 그리지 않는다
    /// (`MODULE.md`의 "시안 대비 알려진 차이").
    private var nickname: some View {
        Text(profile?.nickname ?? "")
            .challaFont(Metric.nicknameTypography)
            .foregroundStyle(CHALLAColor.Label.normal)
            .lineLimit(1)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Metric

private enum Metric {

    static let nicknameTypography = CHALLATypography.body.medium.bold

    /// 아바타와 닉네임 사이 — 시안 실측 16 (아바타 68 아래 텍스트 블록이 y84에서 시작).
    static let avatarToTextSpacing: CGFloat = 16
}

#Preview {
    AccountProfileSummary(
        profile: SettingProfile(nickname: "나는야멋쟁이토마토", avatarURL: nil)
    )
    .padding()
    .background(CHALLAColor.Background.surface)
}
