import CHALLADesignSystem
import ComposableArchitecture
import SwiftUI

/// 초대 코드 입장 드로어 내용. 레이아웃(카드·버튼 규격)은 `CHALLADrawer`가 강제하고
/// 이 뷰는 입력 슬롯(방 코드)만 채운다.
@ViewAction(for: JoinRoomFeature.self)
struct JoinRoomDrawer: View {

    // MARK: - 프로퍼티

    @Bindable var store: StoreOf<JoinRoomFeature>

    // MARK: - Body

    var body: some View {
        CHALLADrawer(
            header: .title("방 입장하기", onClose: { send(.closeButtonTapped) }),
            actions: [
                CHALLADrawerAction("입장하기", isEnabled: store.canSubmit) {
                    send(.joinButtonTapped)
                }
            ]
        ) {
            CHALLATextField(
                text: $store.code,
                placeholder: "방 코드 입력",
                textAlignment: .leading
            )
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

#Preview {
    JoinRoomDrawer(
        store: Store(initialState: JoinRoomFeature.State()) {
            JoinRoomFeature()
        } withDependencies: {
            $0.joinRoomUseCase = .previewValue
        }
    )
    // 드로어는 화면 하단에 붙는 컴포넌트라 프리뷰에서도 그 자리를 만들어 준다.
    .frame(maxHeight: .infinity, alignment: .bottom)
    .background(CHALLAColor.Background.surface)
}
