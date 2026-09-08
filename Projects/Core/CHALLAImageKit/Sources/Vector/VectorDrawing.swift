import CoreGraphics
import SwiftUI

/// 채우기 도형만 담은 벡터 그림. 색은 담지 않는다 — 호출부가 칠한다.
///
/// 서버 커버 스티커는 SVG로만 오는데 iOS는 SVG를 런타임에 디코딩하지 못한다.
/// 그래서 비트맵 대신 다각형 목록으로 들고 있다가 SwiftUI `Path`로 그린다.
public struct VectorDrawing: Equatable, Sendable {

    // MARK: - Properties

    /// 좌표계 크기. viewBox가 있으면 그 크기, 없으면 width/height 속성.
    public let size: CGSize

    /// 닫힌 다각형들. **그리는 순서가 nonzero 감김을 정하므로** 원본 문서 순서를 유지한다.
    public let subpaths: [[CGPoint]]

    public var isEmpty: Bool {
        subpaths.isEmpty
    }

    // MARK: - Initialization

    public init(size: CGSize, subpaths: [[CGPoint]]) {
        self.size = size
        self.subpaths = subpaths
    }

    // MARK: - Public Methods

    /// `size` 좌표계를 `rect`에 가로세로 비율 유지로 채우고(aspect fill) 가운데 정렬한 경로.
    ///
    /// 스티커는 카드를 가득 덮는 장식이라 여백이 생기는 aspect fit이 아니라 fill이다.
    /// 넘치는 부분은 호출부가 `.clipped()`로 자른다.
    public func path(in rect: CGRect) -> Path {
        var path = Path()

        guard !isEmpty, size.width > 0, size.height > 0 else {
            return path
        }

        let scale = max(rect.width / size.width, rect.height / size.height)
        let originX = rect.midX - size.width * scale / 2
        let originY = rect.midY - size.height * scale / 2

        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: originX + point.x * scale,
                y: originY + point.y * scale
            )
        }

        for points in subpaths {
            guard let first = points.first else { continue }

            path.move(to: place(first))

            for point in points.dropFirst() {
                path.addLine(to: place(point))
            }

            path.closeSubpath()
        }

        return path
    }
}
