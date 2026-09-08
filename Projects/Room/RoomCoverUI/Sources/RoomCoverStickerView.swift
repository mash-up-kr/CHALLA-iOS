import CHALLAImageKit
import SwiftUI

/// 서버 커버 스티커를 주어진 색으로 칠해 그린다.
///
/// 서버는 스티커를 SVG로 주는데 iOS는 SVG를 런타임에 디코딩하지 못해, 비트맵이 아니라 도형으로 받아
/// 직접 채운다(`VectorDrawingLoader`). 파일에 박힌 색은 쓰지 않는다 — 같은 도안을 사용자가 고른 색으로 칠해야 한다.
///
/// `url`이 nil이거나, 받아오기 전·실패했을 때는 아무것도 그리지 않는다 — 스티커는 장식이라 자리만 비워 두면 된다.
public struct RoomCoverStickerView: View {

    // MARK: - 프로퍼티와 init

    private let url: URL?
    private let color: Color

    @Environment(\.roomCoverStickerLoader) private var loader
    @State private var drawing: VectorDrawing?

    public init(url: URL?, color: Color) {
        self.url = url
        self.color = color
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if let drawing, !drawing.isEmpty {
                StickerShape(drawing: drawing).fill(color)
            } else {
                Color.clear
            }
        }
        .accessibilityHidden(true) // 장식 — 이름이 필요한 자리는 호출부가 라벨을 붙인다
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            drawing = nil
            return
        }
        drawing = try? await loader.drawing(from: url)
    }
}

/// 채우기 규칙은 SVG 기본값(nonzero)을 그대로 쓴다 — 도안의 구멍이 감김 방향으로 표현돼 있다.
private struct StickerShape: Shape {

    let drawing: VectorDrawing

    func path(in rect: CGRect) -> Path {
        drawing.path(in: rect)
    }
}
