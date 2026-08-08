import CHALLADesignSystem
import SwiftUI
import UserDomain

/// 프로필 설정을 마친 뒤 도착하는 임시 화면.
///
/// 아직 홈(방 목록) 화면이 없어 자리만 잡아 둔다. 홈 모듈이 생기면 `AppView`에서 교체하고 이 View는 제거한다.
/// 설정 버튼도 그때 홈 화면으로 이동한다 — 지금은 설정 진입 경로가 여기뿐이다.
struct HomePlaceholderView: View {

    let profile: UserProfile
    let onSettingTapped: () -> Void

    var body: some View {
        ZStack {
            CHALLAColor.Background.surface
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // TODO: 임의 작성 문구 — 실제 홈 화면으로 교체 예정.
                Text("\(profile.nickname ?? "")님, 환영해요")
                    .challaFont(.heading.small.bold)
                    .foregroundStyle(CHALLAColor.Label.strong)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .overlay(alignment: .topTrailing) { settingButton }
    }

    private var settingButton: some View {
        Button(action: onSettingTapped) {
            CHALLAIcon.setting.image(size: .size24, color: CHALLAColor.Label.alternative)
                .frame(width: Metric.touchArea, height: Metric.touchArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("설정")
        .padding(.trailing, Metric.trailingPadding)
    }
}

private enum Metric {
    /// HIG 최소 터치 타깃(44)을 넘긴다.
    static let touchArea: CGFloat = 48
    static let trailingPadding: CGFloat = 8
}

#Preview {
    HomePlaceholderView(profile: UserProfile(id: 1, nickname: "나는야멋쟁이토마토")) {}
}
