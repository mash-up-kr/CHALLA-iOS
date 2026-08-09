import CHALLADesignSystem
import SwiftUI
import UserDomain

/// 프로필 설정을 마친 뒤 도착하는 임시 화면.
///
/// 아직 홈(방 목록) 화면이 없어 자리만 잡아 둔다. 홈 모듈이 생기면 `AppView`에서 교체하고 이 View는 제거한다.
struct HomePlaceholderView: View {

    let profile: UserProfile

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
    }
}

#Preview {
    HomePlaceholderView(profile: UserProfile(id: 1, nickname: "나는야멋쟁이토마토"))
}
