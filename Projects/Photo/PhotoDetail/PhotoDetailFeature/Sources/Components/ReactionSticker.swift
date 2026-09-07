import PhotoDomain
import SwiftUI

/// 사진 위에 붙은 리액션 스티커 한 장.
struct ReactionSticker: View {

    // MARK: - 프로퍼티

    let kind: ReactionKind
    /// 스티커 한 변 크기(흰 테두리 포함).
    let size: CGFloat

    // MARK: - Body

    var body: some View {
        kind.emoji.stickerImage
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel("\(kind.accessibilityLabel) 리액션")
    }
}
