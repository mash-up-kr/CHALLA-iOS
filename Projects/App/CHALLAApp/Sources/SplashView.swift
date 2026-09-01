import CHALLADesignSystem
import SwiftUI

/// 앱 실행 직후 버전 체크·세션 복원이 도는 동안 보여주는 스플래시 (#98, zpl.io/ggGGAOM).
struct SplashView: View {

    var body: some View {
        ZStack {
            CHALLAColor.Background.surface

            Image("SplashAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
        }
        // 시안은 화면 전체 기준 정중앙이다 — safe area 안에서 재면 아이콘이 아래로 밀린다.
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel("불러오는 중")
    }
}

#Preview {
    SplashView()
}
