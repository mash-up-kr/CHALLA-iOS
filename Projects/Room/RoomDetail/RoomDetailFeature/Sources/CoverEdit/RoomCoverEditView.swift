import CHALLADesignSystem
import ComposableArchitecture
import PhotosUI
import RoomCoverUI
import RoomDomain
import SwiftUI

@ViewAction(for: RoomCoverEditFeature.self)
public struct RoomCoverEditView: View {

    @Bindable public var store: StoreOf<RoomCoverEditFeature>

    public init(store: StoreOf<RoomCoverEditFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            CHALLATopNavigation.sub(
                title: "커버 이미지",
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") { send(.backButtonTapped) }
            )
            ScrollView {
                VStack(spacing: 0) {
                    cardSection
                        .padding(.top, CoverEditMetric.cardTopPadding)
                        .padding(.bottom, CoverEditMetric.cardSectionBottomPadding)
                    divider
                        .padding(.vertical, CoverEditMetric.dividerVerticalSpacing)
                    colorSection
                        .padding(.bottom, CoverEditMetric.colorStickerSpacing)
                    stickerSection
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .overlay(alignment: .top) { toastLayer }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CHALLAColor.Background.surface)
        // 뒤로가기 저장이 도는 동안은 뒤로가기 버튼까지 함께 잠근다 — 응답 전에 나가면 결과가 유실된다.
        .disabled(store.isSaving)
        .overlay(alignment: .topTrailing) { savingLayer }
        .alert($store.scope(state: \.alert, action: \.alert))
        // `.shared()`를 넘겨야 고른 항목 읽기가 앱의 사진첩 권한을 따른다 — 앞단에서 권한을 먼저 묻는 이유.
        .photosPicker(
            isPresented: $store.isPhotoPickerPresented,
            selection: $store.photoPickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .task { send(.task) }
    }

    private var cardSection: some View {
        CoverPreviewCard(
            title: store.title,
            memberCount: store.memberCount,
            cover: store.cover,
            localImageData: store.localImageData
        )
        .overlay(alignment: .bottom) {
            photoActionPill
                .offset(y: CoverEditMetric.pillOverlap)
        }
    }

    /// 아이콘은 24지만 탭 영역은 세로선 양옆 절반(40×40)씩 — 시안 크기(82×40) 안에서 최대한 넓힌다.
    private var photoActionPill: some View {
        HStack(spacing: 0) {
            Button {
                send(.cameraButtonTapped)
            } label: {
                CHALLAIcon.camera.image(size: .size24, color: CHALLAColor.Label.alternative)
                    .padding(.trailing, CoverEditMetric.pillContentSpacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("사진 선택")
            Rectangle()
                .fill(CHALLAColor.Line.normal)
                .frame(width: CoverEditMetric.pillDividerWidth, height: CoverEditMetric.pillDividerHeight)
            Button {
                send(.clearButtonTapped)
            } label: {
                CHALLAIcon.close.image(size: .size24, color: CHALLAColor.Label.alternative)
                    .padding(.leading, CoverEditMetric.pillContentSpacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("커버 지우기")
            .accessibilityHint(store.canClear ? "사진과 스티커를 지웁니다" : "사진이나 스티커가 있을 때만 지울 수 있어요")
        }
        .buttonStyle(.plain)
        .frame(width: CoverEditMetric.pillWidth, height: CoverEditMetric.pillHeight)
        .background {
            Capsule()
                .fill(CHALLAColor.Background.level2)
        }
        .overlay {
            Capsule()
                .strokeBorder(CHALLAColor.Line.normal, lineWidth: CoverEditMetric.borderWidth)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(CHALLAColor.Background.level2)
            .frame(height: CoverEditMetric.dividerHeight)
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: CoverEditMetric.sectionTitleSpacing) {
            sectionTitle("색상")
            HStack(spacing: 0) {
                ForEach(store.options.colors) { color in
                    colorChip(color)
                    if color != store.options.colors.last {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, CoverEditMetric.horizontalPadding)
    }

    private func colorChip(_ color: RoomCoverColor) -> some View {
        let isSelected = store.selectedColor?.id == color.id
        return Button {
            send(.colorTapped(color))
        } label: {
            Circle()
                .fill(color.color)
                .frame(width: CoverEditMetric.chipSize, height: CoverEditMetric.chipSize)
                .overlay {
                    Circle()
                        .strokeBorder(selectionBorderColor(isSelected), lineWidth: CoverEditMetric.borderWidth)
                }
                .contentShape(Circle().expandedToHitTarget(from: CoverEditMetric.chipSize))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.name)
        .accessibilityAddTraits(isSelected ? AccessibilityTraits.isSelected : [])
    }

    private var stickerSection: some View {
        VStack(alignment: .leading, spacing: CoverEditMetric.sectionTitleSpacing) {
            sectionTitle("스티커")
                .padding(.horizontal, CoverEditMetric.horizontalPadding)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CoverEditMetric.stickerSpacing) {
                    // 그림 주소가 없는 선택지는 그릴 것이 없어 셀 자체를 생략한다
                    ForEach(store.options.stickers) { sticker in
                        if sticker.imageURL != nil {
                            stickerCell(sticker)
                        }
                    }
                }
                .padding(.horizontal, CoverEditMetric.horizontalPadding)
            }
        }
    }

    private func stickerCell(_ sticker: RoomCoverStickerOption) -> some View {
        let isSelected = store.cover.sticker?.id == sticker.id
        let color = store.selectedColor ?? store.options.colors.first
        return Button {
            send(.stickerTapped(sticker))
        } label: {
            CHALLAColor.Static.black
                .overlay {
                    RoomCoverStickerView(
                        url: sticker.imageURL,
                        color: color?.color ?? CHALLAColor.Label.neutral
                    )
                }
                .frame(width: CoverEditMetric.stickerWidth, height: CoverEditMetric.stickerHeight)
                .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: CHALLARadius.large)
                        .strokeBorder(selectionBorderColor(isSelected), lineWidth: CoverEditMetric.borderWidth)
                }
        }
        .buttonStyle(.plain)
        // TODO: 서버가 도안 이름을 주지 않아 순번으로 읽는다 — 이름이 생기면 교체할 것.
        .accessibilityLabel(stickerLabel(for: sticker))
        .accessibilityAddTraits(isSelected ? AccessibilityTraits.isSelected : [])
    }

    private func stickerLabel(for sticker: RoomCoverStickerOption) -> String {
        let order = (store.options.stickers.firstIndex { $0.id == sticker.id } ?? 0) + 1
        return "스티커 \(order)"
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .challaFont(.body.medium.bold)
            .foregroundStyle(CHALLAColor.Label.normal)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionBorderColor(_ isSelected: Bool) -> Color {
        isSelected ? CHALLAColor.Static.white : CHALLAColor.Background.level4
    }

    @ViewBuilder
    private var toastLayer: some View {
        if let toast = store.toast {
            CHALLAToast(toast, icon: .error, variant: .negative)
                .padding(.top, CoverEditMetric.toastTopPadding)
        }
    }

    @ViewBuilder
    private var savingLayer: some View {
        if store.isSaving {
            CHALLALoadingDots()
                .frame(height: CoverEditMetric.topBarHeight)
                .padding(.trailing, CoverEditMetric.horizontalPadding)
                .accessibilityHidden(false)
                .accessibilityLabel("커버 저장 중")
        }
    }
}

private struct CoverPreviewCard: View {

    let title: String
    let memberCount: Int
    let cover: RoomCover
    let localImageData: Data?

    var body: some View {
        RoomCoverPhoto(data: localImageData) { localPhoto in
            if let localPhoto {
                card(photo: localPhoto)
            } else {
                CHALLAAsyncImage(url: cover.imageURL) { image in
                    card(photo: image)
                } placeholder: {
                    card(photo: nil)
                }
            }
        }
    }

    private func card(photo: Image?) -> some View {
        CHALLARoomCard(title: title, memberCount: memberCount, photo: photo, variant: .plain) {
            RoomCoverStickerView(
                url: cover.sticker?.imageURL,
                color: cover.sticker?.color.color ?? .clear
            )
        }
    }
}

private enum CoverEditMetric {
    static let horizontalPadding: CGFloat = 16
    static let borderWidth: CGFloat = 2
    static let cardTopPadding: CGFloat = 16
    /// 필 버튼이 카드 밖으로 나온 만큼(20) 아래 여백을 더 준다
    static let cardSectionBottomPadding: CGFloat = 20
    static let pillOverlap: CGFloat = 20
    static let pillWidth: CGFloat = 82
    static let pillHeight: CGFloat = 40
    static let pillContentSpacing: CGFloat = 6
    static let pillDividerWidth: CGFloat = 2
    static let pillDividerHeight: CGFloat = 16
    static let dividerHeight: CGFloat = 8
    static let dividerVerticalSpacing: CGFloat = 32
    static let sectionTitleSpacing: CGFloat = 16
    static let colorStickerSpacing: CGFloat = 28
    static let chipSize: CGFloat = 36
    static let stickerWidth: CGFloat = 100
    static let stickerHeight: CGFloat = 134
    static let stickerSpacing: CGFloat = 8
    static let toastTopPadding: CGFloat = 8
    /// `CHALLATopNavigation` 바 높이 — 저장 중 표시를 바의 빈 trailing 자리에 세로 중앙으로 맞춘다.
    static let topBarHeight: CGFloat = 70
}

@MainActor
private func previewStore(cover: RoomCover, localImageData: Data? = nil) -> StoreOf<RoomCoverEditFeature> {
    var state = RoomCoverEditFeature.State(
        roomID: -1,
        title: "친구들과 유럽 여행",
        memberCount: 12,
        cover: cover
    )
    state.localImageData = localImageData
    return Store(initialState: state) {
        RoomCoverEditFeature()
    } withDependencies: {
        $0.fetchRoomCoverOptionsUseCase = FetchRoomCoverOptionsUseCase(run: { .preview })
        $0.updateRoomCoverUseCase = UpdateRoomCoverUseCase(run: { _, _ in })
        $0.uploadRoomCoverImageUseCase = .previewValue
    }
}

@MainActor
private func previewPhotoData() -> Data? {
    let size = CGSize(width: 400, height: 532)
    return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.85) { context in
        UIColor.systemIndigo.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        UIColor.systemOrange.setFill()
        context.cgContext.fillEllipse(in: CGRect(x: 120, y: 180, width: 160, height: 160))
    }
}

private func previewSticker(colorIndex: Int) -> RoomCoverSticker {
    let options = RoomCoverOptions.preview
    return options.stickers[0].sticker(color: options.colors[colorIndex])
}

#Preview("빈 커버") {
    RoomCoverEditView(store: previewStore(cover: .none))
}

#Preview("스티커만") {
    RoomCoverEditView(store: previewStore(cover: RoomCover(sticker: previewSticker(colorIndex: 0))))
}

#Preview("사진 + 스티커") {
    RoomCoverEditView(
        store: previewStore(cover: RoomCover(sticker: previewSticker(colorIndex: 3)), localImageData: previewPhotoData())
    )
}
