import CHALLADesignSystem
import ComposableArchitecture
import RoomDomain
import SwiftUI

/// 방 선택 드로어 본문. 껍데기(모서리·헤더·구분선)와 등장 연출은 DS의 `CHALLADrawer`를 그대로 쓴다.
struct RoomSelectionDrawer: View {

    let rooms: IdentifiedArrayOf<ShootableRoom>
    let selectedRoomID: ShootableRoom.ID?
    let onSelect: (ShootableRoom.ID) -> Void
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

    let room: ShootableRoom
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(room.title)
                .challaFont(.body.medium.bold)
                .foregroundStyle(isSelected ? CHALLAColor.Label.normal : CHALLAColor.Label.neutral)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            RemainingCardsLabel(remaining: room.remainedPhotoCount, total: room.totalPhotoCount)
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
            ShootableRoom(id: -1, title: "방이름방이름방이름1", remainedPhotoCount: 6, totalPhotoCount: 24),
            ShootableRoom(id: -2, title: "방이름방이름방이름2", remainedPhotoCount: 6, totalPhotoCount: 24),
            ShootableRoom(id: -3, title: "방이름방이름방이름3방이름방이름방이름3", remainedPhotoCount: 3, totalPhotoCount: 48),
            ShootableRoom(id: -4, title: "방이름방이름방이름4", remainedPhotoCount: 3, totalPhotoCount: 48)
        ]),
        selectedRoomID: -2,
        onSelect: { _ in },
        onClose: {}
    )
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(CHALLAColor.Static.black)
}
