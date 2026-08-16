import PhotoDomain
import SwiftUI

/// 사진 위에 붙은 리액션 스티커 한 장.
struct ReactionSticker: View {

    // MARK: - 프로퍼티

    let kind: ReactionKind
    /// 이모지 글리프 크기. 흰 테두리는 이 크기 바깥으로 더 나간다.
    let size: CGFloat

    // MARK: - Body

    var body: some View {
        glyph
            .background { outline }
            .accessibilityElement()
            .accessibilityLabel("\(kind.accessibilityLabel) 리액션")
    }

    private var glyph: some View {
        Text(kind.emoji).font(.system(size: size))
    }

    /// 테두리는 글리프 실루엣을 따라가야 하므로, 흰 실루엣을 여덟 방향으로 밀어 깐다.
    /// 이모지는 색이 박힌 글리프라 `foregroundStyle`이 통하지 않아 채도를 없애고 밝기를 올린다.
    private var outline: some View {
        ZStack {
            ForEach(0 ..< 8) { step in
                let radians = Double(step) * .pi / 4
                glyph
                    .grayscale(1)
                    .brightness(1)
                    .offset(x: cos(radians) * Metric.outlineWidth, y: sin(radians) * Metric.outlineWidth)
            }
        }
    }
}

// MARK: - Figma 실측값

private enum Metric {
    /// 글리프 바깥으로 나가는 테두리 두께 (전체 82 − 글리프 66.5 = 양쪽 8).
    static let outlineWidth: CGFloat = 8
}
