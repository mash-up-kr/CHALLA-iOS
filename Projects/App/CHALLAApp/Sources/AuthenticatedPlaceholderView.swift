import CHALLADesignSystem
import SwiftUI

/// 로그인 성공 직후 임시 화면.
///
/// 아직 메인 화면이 없어 자리만 잡아 둔다.
/// 메인 화면이 생기면 `AppView`에서 `isNewUser` 분기로 각 화면을 연결하고 이 View는 제거한다.
struct AuthenticatedPlaceholderView: View {

    let isNewUser: Bool

    var body: some View {
        ZStack {
            CHALLAColor.Background.surface
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // TODO: 임의 작성 문구 — 실제 화면으로 교체 예정.
                Text("로그인 성공 🎉")
                    .foregroundStyle(CHALLAColor.Label.strong)
                    .accessibilityLabel("로그인 성공") // 이모지 이름("파티 폭죽")까지 읽히지 않게
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }
}
