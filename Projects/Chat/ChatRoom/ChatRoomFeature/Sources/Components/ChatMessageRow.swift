import CHALLADesignSystem
import ChatDomain
import PhotoDomain
import SwiftUI

/// 채팅 메시지 한 줄. 내 메시지는 오른쪽(아바타·이름 없음), 받은 메시지는 왼쪽(아바타 + 이름).
/// 내용은 세 가지: 텍스트 버블 · 사진(+메시지) · 사진에 달린 이모지.
struct ChatMessageRow: View {

    let message: ChatMessage
    let isMine: Bool
    var isPhotoBlurred = false

    var body: some View {
        if isMine {
            // 오른쪽 정렬: 왼쪽 여백을 Spacer가 흡수 → 버블은 내용만큼만, 시간은 버블 바로 왼쪽에 붙는다.
            HStack(alignment: .bottom, spacing: Metric.timeSpacing) {
                Spacer(minLength: Metric.oppositeInset)
                timestamp
                content
            }
        } else {
            HStack(alignment: .bottom, spacing: Metric.avatarSpacing) {
                avatar
                VStack(alignment: .leading, spacing: Metric.nameSpacing) {
                    Text(message.authorName)
                        .challaFont(.body.xsmall.medium)
                        .foregroundStyle(CHALLAColor.Label.neutral)
                    // 오른쪽 여백을 Spacer가 흡수 → 버블은 내용만큼만, 시간은 버블 바로 오른쪽에 붙는다.
                    HStack(alignment: .bottom, spacing: Metric.timeSpacing) {
                        content
                        timestamp
                        Spacer(minLength: Metric.oppositeInset)
                    }
                }
            }
        }
    }

    // MARK: - 내용

    @ViewBuilder
    private var content: some View {
        switch message.kind {
        case .text:
            textBubble(message.content)

        case .photo:
            // 사진 메시지 — content가 있으면 사진과 메시지를 함께 보여준다.
            VStack(alignment: isMine ? .trailing : .leading, spacing: Metric.photoTextSpacing) {
                photoCard
                if !message.content.isEmpty {
                    textBubble(message.content)
                }
            }

        case let .reaction(kind):
            // 사진에 달린 이모지 — 시안처럼 좌상단 모서리에 살짝 기울여 얹는다.
            photoCard
                .overlay(alignment: .topLeading) {
                    kind.emoji.stickerImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: Metric.stickerSize, height: Metric.stickerSize)
                        .rotationEffect(.degrees(Metric.stickerRotation))
                        .offset(x: Metric.stickerOffset, y: Metric.stickerOffset)
                        .accessibilityElement()
                        .accessibilityLabel("\(kind.accessibilityLabel) 리액션")
                }
        }
    }

    private func textBubble(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.medium.medium)
            .foregroundStyle(isMine ? CHALLAColor.Static.black : CHALLAColor.Label.normal)
            .padding(.vertical, Metric.bubbleVerticalPadding)
            .padding(.horizontal, Metric.bubbleHorizontalPadding)
            .background(
                isMine ? CHALLAColor.Static.white : CHALLAColor.Background.level4,
                in: RoundedRectangle(cornerRadius: Metric.bubbleRadius)
            )
    }

    /// 이미지 원본 크기가 레이아웃에 영향을 주지 않도록 카드 크기를 먼저 고정한다.
    private var photoCard: some View {
        Color.clear
            .frame(width: Metric.photoWidth, height: Metric.photoHeight)
            .overlay {
                CHALLAAsyncImage(url: message.photoImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        // 블러로 가장자리가 투명해지지 않도록 이미지를 확장한다.
                        .padding(isPhotoBlurred ? -Metric.blurEdgeBleed : 0)
                        .blur(radius: isPhotoBlurred ? Metric.photoBlurRadius : 0)
                } placeholder: {
                    CHALLAColor.Background.level2
                }
            }
            .overlay {
                if isPhotoBlurred {
                    CHALLAColor.Static.white.opacity(Metric.veilOpacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Metric.photoRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metric.photoRadius)
                    .strokeBorder(CHALLAColor.Line.neutral, lineWidth: 1)
            )
    }

    private var avatar: some View {
        CHALLAAvatar(photo: nil, size: Metric.avatarSize)
            .overlay {
                if let url = message.authorImageURL {
                    CHALLAAsyncImage(url: url)
                        .frame(width: Metric.avatarSize, height: Metric.avatarSize)
                        .clipShape(Circle())
                }
            }
    }

    private var timestamp: some View {
        Text(Self.timeFormatter.string(from: message.createdAt))
            .challaFont(.body.xsmall.regular)
            .foregroundStyle(CHALLAColor.Label.neutral)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()
}

private enum Metric {
    static let avatarSize: CGFloat = 22
    static let avatarSpacing: CGFloat = 8
    static let timeSpacing: CGFloat = 6
    static let nameSpacing: CGFloat = 4
    static let oppositeInset: CGFloat = 40
    static let bubbleRadius: CGFloat = 12
    static let bubbleVerticalPadding: CGFloat = 8
    static let bubbleHorizontalPadding: CGFloat = 12
    static let photoWidth: CGFloat = 82
    static let photoHeight: CGFloat = 109.33
    static let photoRadius: CGFloat = 10
    static let photoTextSpacing: CGFloat = 4
    /// 방 상세 필름 카드와 동일한 블러 반경.
    static let photoBlurRadius: CGFloat = 13.5
    static let blurEdgeBleed: CGFloat = photoBlurRadius * 2
    static let veilOpacity: Double = 0.05
    /// 사진 위에 얹는 이모지 크기·기울기·모서리 오프셋(시안: 좌상단, 10°).
    static let stickerSize: CGFloat = 44
    static let stickerRotation: Double = 10
    static let stickerOffset: CGFloat = -8
}
