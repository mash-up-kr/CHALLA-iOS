import CHALLADesignSystem
import ComposableArchitecture
import SwiftUI

/// 방 선택 드로어 본문. 껍데기(모서리·헤더·구분선)와 등장 연출은 DS의 `CHALLADrawer`를 그대로 쓴다.
struct RoomSelectionDrawer: View {

    let rooms: IdentifiedArrayOf<CameraRoom>
    let selectedRoomID: CameraRoom.ID?
    let onSelect: (CameraRoom.ID) -> Void
    let onClose: () -> Void

    var body: some View {
        CHALLADrawer(header: .title("방 선택하기", onClose: onClose)) {
            ScrollView {
                VStack(spacing: RoomSelectionDrawerMetric.rowSpacing) {
                    ForEach(rooms) { room in
                        Button {
                            onSelect(room.id)
                        } label: {
                            RoomListRow(room: room, isSelected: room.id == selectedRoomID)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: RoomSelectionDrawerMetric.maxHeight)
        }
    }
}

private struct RoomListRow: View {

    let room: CameraRoom
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(room.name)
                .challaFont(.body.medium.bold)
                .foregroundStyle(isSelected ? CHALLAColor.Label.normal : CHALLAColor.Label.neutral)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            RemainingCardsLabel(remaining: room.remainingCards, total: room.totalCards)
        }
        .padding(.horizontal, RoomSelectionDrawerMetric.rowHorizontalPadding)
        .frame(height: RoomSelectionDrawerMetric.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: CHALLARadius.large)
                .fill(isSelected ? CHALLAColor.Background.level4 : CHALLAColor.Background.level2)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: CHALLARadius.large)
                    .strokeBorder(CHALLAColor.Line.normal, lineWidth: RoomSelectionDrawerMetric.rowBorderWidth)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: CHALLARadius.large))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Figma 실측값

private enum RoomSelectionDrawerMetric {
    static let rowHeight: CGFloat = 52
    static let rowSpacing: CGFloat = 8
    static let rowHorizontalPadding: CGFloat = 20
    static let rowBorderWidth: CGFloat = 1.5
    /// 4행(52×4 + 8×3)까지 펼치고 그 이상은 스크롤한다.
    static let maxHeight: CGFloat = 232
}

#Preview {
    RoomSelectionDrawer(
        rooms: IdentifiedArray(uniqueElements: [
            CameraRoom(id: "1", name: "방이름방이름방이름1", remainingCards: 6, totalCards: 24),
            CameraRoom(id: "2", name: "방이름방이름방이름2", remainingCards: 6, totalCards: 24),
            CameraRoom(id: "3", name: "방이름방이름방이름3방이름방이름방이름3", remainingCards: 3, totalCards: 48),
            CameraRoom(id: "4", name: "방이름방이름방이름4", remainingCards: 3, totalCards: 48)
        ]),
        selectedRoomID: "2",
        onSelect: { _ in },
        onClose: {}
    )
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(CHALLAColor.Static.black)
}
