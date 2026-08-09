import CHALLADesignSystem
import SwiftUI

/// 앱 실행 직후 내 프로필을 조회하는 동안 보여주는 화면.
struct LaunchingView: View {

    var body: some View {
        ZStack {
            CHALLAColor.Background.surface
                .ignoresSafeArea()

            CHALLALoadingDots()
        }
        .accessibilityElement()
        .accessibilityLabel("불러오는 중")
    }
}

#Preview {
    LaunchingView()
}
