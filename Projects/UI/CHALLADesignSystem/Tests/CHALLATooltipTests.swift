@testable import CHALLADesignSystem
import SwiftUI
import Testing

/// 툴팁 모양(말풍선+화살표 합성 패스)의 기하 검증.
/// 화살표가 어느 모서리에 붙는지는 갤러리 육안으로 보이지만, 방향×정렬 조합의
/// 좌표 계산과 패스 합성(겹침 구멍) 회귀는 눈으로 잡기 어려워 테스트로 고정한다.
struct CHALLATooltipTests {

    private static let rect = CGRect(x: 0, y: 0, width: 200, height: 50)
    private static let positions: [CHALLATooltip.Position] = [.top, .bottom, .leading, .trailing]

    private func shape(
        _ position: CHALLATooltip.Position,
        _ alignment: CHALLATooltip.ArrowAlignment = .center
    ) -> TooltipShape {
        TooltipShape(position: position, arrowAlignment: alignment)
    }

    @Test("말풍선 몸통은 화살표 모서리 쪽에서만 8을 내준다", arguments: [
        (CHALLATooltip.Position.top, CGRect(x: 0, y: 0, width: 200, height: 42)),
        (.bottom, CGRect(x: 0, y: 8, width: 200, height: 42)),
        (.leading, CGRect(x: 0, y: 0, width: 192, height: 50)),
        (.trailing, CGRect(x: 8, y: 0, width: 192, height: 50))
    ])
    func bubbleLeavesArrowArea(position: CHALLATooltip.Position, expected: CGRect) {
        #expect(shape(position).bubbleRect(in: Self.rect) == expected)
    }

    @Test("화살표는 말풍선 밖 화살표 영역으로 돌출된다 — 방향별 중앙 정렬 기준")
    func arrowProtrudesTowardAnchor() {
        // 각 방향의 화살표 중심선에서 모서리 밖 3pt 지점 (돌출 약 6 이내).
        let tips: [(CHALLATooltip.Position, CGPoint)] = [
            (.top, CGPoint(x: 100, y: 45)),
            (.bottom, CGPoint(x: 100, y: 5)),
            (.leading, CGPoint(x: 195, y: 25)),
            (.trailing, CGPoint(x: 5, y: 25))
        ]
        for (position, tip) in tips {
            let path = shape(position).path(in: Self.rect)
            #expect(path.contains(tip), "\(position) 화살표가 \(tip)을 덮지 않는다")
        }
    }

    @Test("화살표 정렬 — 가로 모서리에서 leading·trailing은 끝에서 8 안쪽에 붙는다")
    func arrowAlignmentAlongHorizontalEdge() {
        // leading: 밑변 8~28의 중심 x=18 · trailing: 172~192의 중심 x=182.
        let leading = shape(.top, .leading).path(in: Self.rect)
        #expect(leading.contains(CGPoint(x: 18, y: 45)))
        #expect(!leading.contains(CGPoint(x: 100, y: 45)))
        #expect(!leading.contains(CGPoint(x: 182, y: 45)))

        let trailing = shape(.top, .trailing).path(in: Self.rect)
        #expect(trailing.contains(CGPoint(x: 182, y: 45)))
        #expect(!trailing.contains(CGPoint(x: 18, y: 45)))
    }

    @Test("화살표 정렬 — 세로 모서리에서 leading은 위, trailing은 아래에 붙는다")
    func arrowAlignmentAlongVerticalEdge() {
        // leading: 밑변 8~28의 중심 y=18 · trailing: 22~42의 중심 y=32.
        let leading = shape(.leading, .leading).path(in: Self.rect)
        #expect(leading.contains(CGPoint(x: 195, y: 18)))
        #expect(!leading.contains(CGPoint(x: 195, y: 32)))

        let trailing = shape(.leading, .trailing).path(in: Self.rect)
        #expect(trailing.contains(CGPoint(x: 195, y: 32)))
        #expect(!trailing.contains(CGPoint(x: 195, y: 18)))
    }

    @Test("화살표 밑변이 말풍선과 겹치는 자리에 구멍이 없다 — union 회귀")
    func unionLeavesNoHoleAtArrowBase() {
        for position in Self.positions {
            let path = shape(position).path(in: Self.rect)
            let bubble = shape(position).bubbleRect(in: Self.rect)
            // 화살표 겹침 폭(1pt) 안쪽의 몸통 지점.
            let insidePoints = [
                CGPoint(x: bubble.midX, y: bubble.maxY - 0.5),
                CGPoint(x: bubble.midX, y: bubble.minY + 0.5),
                CGPoint(x: bubble.maxX - 0.5, y: bubble.midY),
                CGPoint(x: bubble.minX + 0.5, y: bubble.midY)
            ]
            for point in insidePoints {
                #expect(path.contains(point), "\(position)에서 \(point)이 비어 있다")
            }
        }
    }

    @Test("패스는 주어진 rect를 벗어나지 않는다", arguments: [
        CHALLATooltip.ArrowAlignment.leading, .center, .trailing
    ])
    func pathStaysInsideRect(alignment: CHALLATooltip.ArrowAlignment) {
        for position in Self.positions {
            let bounds = shape(position, alignment).path(in: Self.rect).boundingRect
            #expect(Self.rect.insetBy(dx: -0.001, dy: -0.001).contains(bounds))
        }
    }
}
