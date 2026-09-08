@testable import CHALLAImageKit
import CoreGraphics
import Foundation
import Testing

struct SVGShapeParserTests {

    private let parser = SVGShapeParser()

    private func parse(_ svg: String) throws -> VectorDrawing {
        try parser.parse(Data(svg.utf8))
    }

    // MARK: - 크기

    @Test("viewBox에서 좌표계 크기를 읽는다")
    func readsSizeFromViewBox() throws {
        let drawing = try parse(
            """
            <svg width="410" height="544" viewBox="0 0 205 272">
            <rect x="0" y="0" width="10" height="10"/>
            </svg>
            """
        )

        #expect(drawing.size == CGSize(width: 205, height: 272))
    }

    @Test("viewBox가 없으면 width/height 속성을 쓴다")
    func fallsBackToWidthAndHeight() throws {
        let drawing = try parse(
            """
            <svg width="100" height="50">
            <rect width="10" height="10"/>
            </svg>
            """
        )

        #expect(drawing.size == CGSize(width: 100, height: 50))
    }

    @Test("viewBox 원점이 0이 아니면 좌표를 원점으로 옮긴다")
    func normalizesViewBoxOrigin() throws {
        let drawing = try parse(
            """
            <svg viewBox="10 20 100 100">
            <rect x="10" y="20" width="10" height="10"/>
            </svg>
            """
        )

        #expect(drawing.subpaths.first?.first == CGPoint(x: 0, y: 0))
    }

    // MARK: - 도형

    @Test("rect는 네 점 다각형이 된다")
    func parsesRect() throws {
        let drawing = try parse(
            """
            <svg viewBox="0 0 100 100">
            <rect x="10" y="20" width="30" height="40" fill="#D5F700"/>
            </svg>
            """
        )

        #expect(drawing.subpaths == [[
            CGPoint(x: 10, y: 20),
            CGPoint(x: 40, y: 20),
            CGPoint(x: 40, y: 60),
            CGPoint(x: 10, y: 60)
        ]])
    }

    @Test("x·y가 없는 rect는 원점 기준이고, 크기가 0이면 버린다")
    func skipsZeroSizedRect() throws {
        let drawing = try parse(
            """
            <svg viewBox="0 0 100 100">
            <rect width="0" height="10"/>
            <rect width="10" height="10"/>
            </svg>
            """
        )

        #expect(drawing.subpaths.count == 1)
        #expect(drawing.subpaths[0][0] == CGPoint(x: 0, y: 0))
    }

    @Test("절대 명령 M·H·V·Z path를 읽는다")
    func parsesAbsolutePath() throws {
        let drawing = try parse(
            """
            <svg viewBox="0 0 100 100">
            <path d="M10 10H50V50H10Z"/>
            </svg>
            """
        )

        #expect(drawing.subpaths == [[
            CGPoint(x: 10, y: 10),
            CGPoint(x: 50, y: 10),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 10, y: 50)
        ]])
    }

    @Test("상대 명령 m·h·v·l·z path를 읽는다")
    func parsesRelativePath() throws {
        let drawing = try parse(
            """
            <svg viewBox="0 0 100 100">
            <path d="m10 10 h40 v40 l-40 0 z"/>
            </svg>
            """
        )

        #expect(drawing.subpaths == [[
            CGPoint(x: 10, y: 10),
            CGPoint(x: 50, y: 10),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 10, y: 50)
        ]])
    }

    @Test("Z 뒤에 오는 서브패스는 각각 별도 다각형이다")
    func parsesMultipleSubpaths() throws {
        let drawing = try parse(
            """
            <svg viewBox="0 0 100 100">
            <path d="M0 0H10V10H0ZM50 50H60V60H50Z"/>
            </svg>
            """
        )

        #expect(drawing.subpaths.count == 2)
        #expect(drawing.subpaths[1].first == CGPoint(x: 50, y: 50))
    }

    @Test("rect와 path가 섞이면 문서 순서를 유지한다")
    func keepsDocumentOrder() throws {
        let drawing = try parse(
            """
            <svg viewBox="0 0 100 100">
            <rect x="0" y="0" width="10" height="10"/>
            <path d="M50 50H60V60H50Z"/>
            <rect x="80" y="80" width="10" height="10"/>
            </svg>
            """
        )

        #expect(drawing.subpaths.count == 3)
        #expect(drawing.subpaths[0].first == CGPoint(x: 0, y: 0))
        #expect(drawing.subpaths[1].first == CGPoint(x: 50, y: 50))
        #expect(drawing.subpaths[2].first == CGPoint(x: 80, y: 80))
    }

    @Test("곡선이 낀 서브패스만 버리고 나머지는 남긴다")
    func dropsOnlyUnsupportedSubpath() throws {
        let drawing = try parse(
            """
            <svg viewBox="0 0 100 100">
            <path d="M0 0H10V10H0ZM20 20C25 20 30 25 30 30ZM50 50H60V60H50Z"/>
            </svg>
            """
        )

        #expect(drawing.subpaths.count == 2)
        #expect(drawing.subpaths[0].first == CGPoint(x: 0, y: 0))
        #expect(drawing.subpaths[1].first == CGPoint(x: 50, y: 50))
    }

    @Test("점이 3개 미만인 서브패스는 면적이 없어 버린다")
    func dropsDegenerateSubpath() throws {
        let drawing = try parse(
            """
            <svg viewBox="0 0 100 100">
            <path d="M0 0H10Z M50 50H60V60H50Z"/>
            </svg>
            """
        )

        #expect(drawing.subpaths.count == 1)
        #expect(drawing.subpaths[0].first == CGPoint(x: 50, y: 50))
    }

    @Test("clipPath·defs 안의 도형은 그리지 않는다")
    func ignoresClipPathContents() throws {
        let drawing = try parse(
            """
            <svg viewBox="0 0 100 100">
            <g clip-path="url(#clip0)">
            <rect x="10" y="10" width="10" height="10"/>
            </g>
            <defs>
            <clipPath id="clip0">
            <rect width="100" height="100" fill="white"/>
            </clipPath>
            </defs>
            </svg>
            """
        )

        #expect(drawing.subpaths.count == 1)
        #expect(drawing.subpaths[0][0] == CGPoint(x: 10, y: 10))
    }

    @Test("서버 스티커와 같은 모양의 문서를 읽는다")
    func parsesServerStickerShape() throws {
        let drawing = try parse(
            """
            <svg width="205" height="272" viewBox="0 0 205 272" fill="none" xmlns="http://www.w3.org/2000/svg">
            <g clip-path="url(#clip0_6353_77882)">
            <rect x="126.482" y="26.1543" width="13.0773" height="13.0773" fill="#D5F700"/>
            <path d="M204.333 271.761H139.559V130.771H165.712V-0.00195312H204.333V271.761Z\
            M152.635 248.467V261.544H165.712V248.467H152.635Z" fill="#D5F700"/>
            <rect x="126.482" y="39.2314" width="13.0773" height="13.0773" fill="#D5F700"/>
            </g>
            <defs>
            <clipPath id="clip0_6353_77882">
            <rect width="204.333" height="271.763" fill="white"/>
            </clipPath>
            </defs>
            </svg>
            """
        )

        #expect(drawing.size == CGSize(width: 205, height: 272))
        #expect(drawing.subpaths.count == 4)
        #expect(drawing.isEmpty == false)

        // 지수 표기 없는 음수 좌표까지 읽는지 — path의 두 번째 점은 H 명령 결과다.
        #expect(drawing.subpaths[1][1] == CGPoint(x: 139.559, y: 271.761))
    }

    // MARK: - 실패

    @Test("크기를 읽을 수 없으면 실패한다")
    func throwsWhenSizeMissing() throws {
        #expect(throws: VectorDrawingError.missingSize) {
            try parse(
                """
                <svg fill="none">
                <rect width="10" height="10"/>
                </svg>
                """
            )
        }
    }

    @Test("도형이 하나도 없으면 실패한다")
    func throwsWhenNoShapes() throws {
        #expect(throws: VectorDrawingError.noShapes) {
            try parse(#"<svg viewBox="0 0 100 100"><g/></svg>"#)
        }
    }

    @Test("모든 서브패스가 곡선이면 도형이 남지 않아 실패한다")
    func throwsWhenEveryPathUnsupported() throws {
        #expect(throws: VectorDrawingError.noShapes) {
            try parse(#"<svg viewBox="0 0 100 100"><path d="M0 0C5 0 10 5 10 10Z"/></svg>"#)
        }
    }

    @Test("UTF-8이 아닌 바이트는 실패한다")
    func throwsOnBrokenData() throws {
        #expect(throws: VectorDrawingError.invalidEncoding) {
            try parser.parse(Data([0xFF, 0xFE, 0xFD, 0x00, 0xC0]))
        }
    }

    @Test("SVG가 아닌 텍스트는 크기 부재로 실패한다")
    func throwsOnNonSVGText() throws {
        #expect(throws: VectorDrawingError.missingSize) {
            try parse("not an svg at all")
        }
    }
}
