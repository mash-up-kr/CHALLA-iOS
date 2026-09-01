import CHALLADesignSystem
import ComposableArchitecture
import SwiftUI

/// 방 이름 수정 드로어 내용. 레이아웃(카드·버튼 규격)은 `CHALLADrawer`가 강제하고
/// 이 뷰는 이름 입력 슬롯만 채운다.
@ViewAction(for: RenameRoomFeature.self)
struct RenameRoomDrawer: View {

    // MARK: - 프로퍼티

    @Bindable var store: StoreOf<RenameRoomFeature>

    // MARK: - Body

    var body: some View {
        CHALLADrawer(
            header: .title("방 이름", onClose: { send(.closeButtonTapped) }),
            actions: [
                CHALLADrawerAction("변경", isEnabled: store.canSubmit) {
                    send(.submitButtonTapped)
                }
            ]
        ) {
            CHALLATextField(
                text: $store.name,
                placeholder: "방 이름 입력",
                textAlignment: .leading
            )
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

#Preview {
    RenameRoomDrawer(
        store: Store(initialState: RenameRoomFeature.State(roomID: -1, title: "친구들과 강릉 여행")) {
            RenameRoomFeature()
        } withDependencies: {
            $0.updateRoomTitleUseCase = .previewValue
        }
    )
    // 드로어는 화면 하단에 붙는 컴포넌트라 프리뷰에서도 그 자리를 만들어 준다.
    .frame(maxHeight: .infinity, alignment: .bottom)
    .background(CHALLAColor.Background.surface)
}
