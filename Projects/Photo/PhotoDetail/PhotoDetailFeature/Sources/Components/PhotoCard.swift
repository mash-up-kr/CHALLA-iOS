import CHALLADesignSystem
import PhotoDomain
import SwiftUI

/// 사진 한 장을 크게 보여주는 카드. 촬영자 표시와 리액션 스티커를 사진 위에 얹는다.
struct PhotoCard: View {

    /// 사진 카드 가로:세로 (실측 358 × 477). 호출부가 카드 크기를 잡는 데 쓴다.
    static let aspectRatio: CGFloat = 3.0 / 4.0

    // MARK: - 프로퍼티

    let photo: Photo
    /// 스티커 자리
    let slots: [String: Int]

    // MARK: - Body

    var body: some View {
        // scaledToFill 이미지가 카드보다 커질 수 있어, Color.clear로 카드 크기를 고정한다.
        Color.clear
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay { image }
            .overlay { scrim }
            .overlay { stickers }
            .overlay(alignment: .top) {
                PhotoAuthorHeader(author: photo.author, capturedAt: photo.capturedAt)
                    .padding(.top, Metric.headerTopPadding)
            }
            .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.xxlarge))
            .overlay {
                RoundedRectangle(cornerRadius: CHALLARadius.xxlarge)
                    .strokeBorder(CHALLAColor.Line.normal, lineWidth: 1)
            }
            .accessibilityLabel(Text("\(photo.author.nickname)님이 \(PhotoAuthorHeader.formatted(photo.capturedAt))에 찍은 사진"))
    }

    // MARK: - 레이어

    private var image: some View {
        CHALLAAsyncImage(url: photo.imageURL) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            // 실패, 로딩 같은 UI
            CHALLAColor.Background.level2
        }
    }

    /// 상단을 어둡게 처리한다. 밝은 사진에서도 촬영자 글자가 보이게 한다.
    private var scrim: some View {
        LinearGradient(
            colors: [CHALLAColor.Static.black.opacity(Metric.scrimOpacity), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 스티커 위치가 사진 크기 대비 비율이라, GeometryReader로 실제 크기를 받아 배치한다.
    private var stickers: some View {
        GeometryReader { proxy in
            ForEach(StickerLayout.placements(for: photo, slots: slots), id: \.reaction.id) { reaction, placement in
                ReactionSticker(kind: reaction.kind, size: Metric.stickerSize)
                    .rotationEffect(.degrees(placement.angleDegrees))
                    .position(
                        x: proxy.size.width * placement.xRatio,
                        y: proxy.size.height * placement.yRatio
                    )
            }
        }
    }
}

// MARK: - Figma 실측값

private enum Metric {
    static let scrimOpacity: Double = 0.6
    static let headerTopPadding: CGFloat = 32
    static let stickerSize: CGFloat = 82
}
