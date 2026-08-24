import CHALLADesignSystem
import ComposableArchitecture
import SwiftUI

/// 방 설정 화면 — 상단 바 + 설정 항목 카드(방 이름 · 커버 이미지).
@ViewAction(for: RoomSettingsFeature.self)
public struct RoomSettingsView: View {

    @Bindable public var store: StoreOf<RoomSettingsFeature>

    public init(store: StoreOf<RoomSettingsFeature>) {
        self.store = store
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            CHALLATopNavigation.sub(
                title: "방 설정",
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") { send(.backButtonTapped) }
            )
            CHALLAListSection {
                CHALLAListRow(
                    "방 이름",
                    icon: .pencilSimple,
                    accessory: .arrow(value: store.title),
                    // 시안이 값 글자를 테마색이 아닌 기본 글자색으로 그린다 — 디자이너 확인 예정.
                    themeColor: CHALLAColor.Label.normal
                ) { send(.renameRowTapped) }
                CHALLAListRow(
                    "커버 이미지",
                    icon: .image,
                    accessory: .arrow(value: nil)
                ) { send(.coverRowTapped) }
            }
            .padding(.horizontal, RoomSettingsMetric.horizontalPadding)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CHALLAColor.Background.surface)
    }
}

// MARK: - Figma 실측값

private enum RoomSettingsMetric {
    /// 좌우 가장자리 여백. 카드는 상단 바 바로 아래 붙는다 (시안 top 114 = 바 높이).
    static let horizontalPadding: CGFloat = 16
}

#Preview {
    RoomSettingsView(
        store: Store(initialState: RoomSettingsFeature.State(roomID: -1, title: "친구들과 강릉 여행")) {
            RoomSettingsFeature()
        }
    )
}
