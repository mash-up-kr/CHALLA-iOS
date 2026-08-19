import CHALLADesignSystem
import PhotoDomain
import SwiftUI

/// 사진 한 장을 크게 보여주는 카드. 촬영자 표시와 리액션 스티커를 사진 위에 얹는다.
struct PhotoCard: View {

    /// 사진 카드 가로:세로 (실측 358 × 477). 호출부가 카드 크기를 잡는 데 쓴다.
    static let aspectRatio: CGFloat = 3.0 / 4.0

    // MARK: - 프로퍼티

    let photo: Photo

    // MARK: - Body

    var body: some View {
        // scaledToFill한 사진이 카드 밖으로 넘치므로 Color.clear가 카드 크기를 잡는다.
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
                    .strokeBorder(CHALLAColor.Line.normal, lineWidth: Metric.borderWidth)
            }
            .accessibilityLabel(Text("\(photo.author.nickname)님이 \(PhotoAuthorHeader.formatted(photo.capturedAt))에 찍은 사진"))
    }

    // MARK: - 레이어

    /// 캐시가 없어 다시 그릴 때마다 다시 받는다 — `CHALLAImageKit`(#25)이 생기면 이 자리를 바꾼다.
    private var image: some View {
        AsyncImage(url: photo.imageURL) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                // 실패와 로딩을 같은 모습으로 둔다 — 시안에 실패 표현이 없다.
                CHALLAColor.Background.level2
            }
        }
    }

    /// 위쪽이 어두워지는 막 — 밝은 사진에서도 촬영자 글자가 읽히게 한다.
    private var scrim: some View {
        LinearGradient(
            colors: [CHALLAColor.Static.black.opacity(Metric.scrimOpacity), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 스티커 자리는 사진 크기에 대한 비율이라 실제 크기를 알아야 놓을 수 있다.
    private var stickers: some View {
        GeometryReader { proxy in
            ForEach(StickerLayout.placements(for: photo), id: \.reaction.id) { reaction, placement in
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
    /// 스티커 이모지 글리프 (실측 66.5 — 흰 테두리를 더하면 82).
    static let stickerSize: CGFloat = 66.5
    static let borderWidth: CGFloat = 1
}
