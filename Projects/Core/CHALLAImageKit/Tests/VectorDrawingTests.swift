@testable import CHALLAImageKit
import CoreGraphics
import Testing

struct VectorDrawingTests {

    /// 좌표계를 가득 채우는 정사각형 하나짜리 그림.
    private let square = VectorDrawing(
        size: CGSize(width: 10, height: 10),
        subpaths: [[
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 10, y: 10),
            CGPoint(x: 0, y: 10)
        ]]
    )

    @Test("도형이 없으면 isEmpty")
    func reportsEmpty() {
        #expect(VectorDrawing(size: CGSize(width: 10, height: 10), subpaths: []).isEmpty)
        #expect(square.isEmpty == false)
    }

    @Test("가로가 긴 rect에서는 가로를 채우고 세로로 넘친다")
    func fillsWiderRect() {
        let bounds = square.path(in: CGRect(x: 0, y: 0, width: 100, height: 50)).boundingRect

        #expect(bounds == CGRect(x: 0, y: -25, width: 100, height: 100))
    }

    @Test("세로가 긴 rect에서는 세로를 채우고 가로로 넘친다")
    func fillsTallerRect() {
        let bounds = square.path(in: CGRect(x: 0, y: 0, width: 50, height: 100)).boundingRect

        #expect(bounds == CGRect(x: -25, y: 0, width: 100, height: 100))
    }

    @Test("rect 원점이 0이 아니어도 그 안에서 가운데 정렬한다")
    func centersInsideOffsetRect() {
        let bounds = square.path(in: CGRect(x: 20, y: 40, width: 100, height: 100)).boundingRect

        #expect(bounds == CGRect(x: 20, y: 40, width: 100, height: 100))
    }

    @Test("도형이 없으면 빈 경로")
    func emptyDrawingMakesEmptyPath() {
        let drawing = VectorDrawing(size: CGSize(width: 10, height: 10), subpaths: [])

        #expect(drawing.path(in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty)
    }
}
