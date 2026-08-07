import CHALLADesignSystem
import ComposableArchitecture
import RoomDomain
import SwiftUI

/// 방 만들기 드로어 내용. 레이아웃(카드·버튼 규격)은 `CHALLADrawer`가 강제하고
/// 이 뷰는 입력 슬롯(이름·촬영 매수)만 채운다.
@ViewAction(for: CreateRoomFeature.self)
struct CreateRoomDrawer: View {

    // MARK: - 프로퍼티

    @Bindable var store: StoreOf<CreateRoomFeature>

    // MARK: - Body

    var body: some View {
        CHALLADrawer(
            header: .title("방 만들기", onClose: { send(.closeButtonTapped) }),
            actions: [
                CHALLADrawerAction("만들기", isEnabled: store.canSubmit) {
                    send(.createButtonTapped)
                }
            ]
        ) {
            VStack(spacing: DrawerMetric.fieldQuestionSpacing) {
                CHALLATextField(
                    text: $store.name,
                    placeholder: "방 이름 입력",
                    textAlignment: .leading
                )

                VStack(spacing: DrawerMetric.questionSelectorSpacing) {
                    Text("얼마나 찍을까요?")
                        .challaFont(.body.xsmall.medium)
                        .foregroundStyle(CHALLAColor.Label.alternative)
                    CHALLAPhotoCountSelector(
                        counts: RoomShotCount.allCases.map(\.rawValue),
                        selected: store.shotCount.rawValue
                    ) { selectedCount in
                        send(.shotCountSelected(RoomShotCount(rawValue: selectedCount) ?? .default))
                    }
                }
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

// MARK: - Figma 실측값

private enum DrawerMetric {
    /// 이름 입력과 "얼마나 찍을까요?" 사이.
    static let fieldQuestionSpacing: CGFloat = 21
    /// 질문 문구와 매수 선택 줄 사이.
    static let questionSelectorSpacing: CGFloat = 12
}

#Preview {
    CreateRoomDrawer(
        store: Store(initialState: CreateRoomFeature.State()) {
            CreateRoomFeature()
        } withDependencies: {
            $0.createRoomUseCase = .previewValue
        }
    )
    .frame(maxHeight: .infinity, alignment: .bottom)
    .background(CHALLAColor.Background.surface)
}
