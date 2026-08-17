import SwiftUI

/// 특정 요소를 가리키는 안내 말풍선. 화살표 방향과 위치를 골라 앵커의 상·하·좌·우 어디로든 띄운다.
///
/// 표시 시점과 배치는 담는 쪽 책임이다 — 이 뷰는 모양만 그린다 (`CHALLAToast`와 동일 정책).
/// 폭은 내용만큼만 넓어지고(최소 64) 최대 폭에 닿으면 줄바꿈된다.
///
/// ```swift
/// CHALLATooltip("메시지에 마침표를 찍어요.")
/// CHALLATooltip("첫 번째 채팅을 보내보세요!", position: .bottom, arrowAlignment: .center)
/// ```
public struct CHALLATooltip: View {

    // MARK: - 공개 타입

    /// 앵커 기준 툴팁이 놓이는 방향 (시안 `position`).
    /// 화살표는 반대편 모서리에 붙어 앵커를 가리킨다.
    public enum Position: Sendable {
        /// top — 앵커 위. 화살표가 아래 모서리에서 아래를 가리킨다.
        case top
        /// bottom — 앵커 아래. 화살표가 위 모서리에서 위를 가리킨다.
        case bottom
        /// left — 앵커 왼쪽. 화살표가 trailing 모서리에서 오른쪽을 가리킨다.
        case leading
        /// right — 앵커 오른쪽. 화살표가 leading 모서리에서 왼쪽을 가리킨다.
        case trailing

        /// 화살표가 붙는 모서리 (툴팁이 놓이는 방향의 반대편).
        var arrowEdge: Edge {
            switch self {
            case .top: .bottom
            case .bottom: .top
            case .leading: .trailing
            case .trailing: .leading
            }
        }
    }

    /// 화살표가 모서리를 따라 붙는 위치 (시안 `align`).
    /// 가로 모서리에서는 leading=왼쪽, 세로 모서리에서는 leading=위다.
    public enum ArrowAlignment: Sendable {
        case leading
        case center
        case trailing
    }

    // MARK: - 프로퍼티와 init

    private let message: String
    private let position: Position
    private let arrowAlignment: ArrowAlignment

    /// - Parameters:
    ///   - message: 말풍선 문구. 내용 폭 256에서 줄바꿈된다.
    ///   - position: 앵커 기준 툴팁이 놓이는 방향. 기본 `.top`(앵커 위에서 아래를 가리킴).
    ///   - arrowAlignment: 화살표가 모서리에 붙는 위치. 기본 `.leading`(시안 default).
    public init(
        _ message: String,
        position: Position = .top,
        arrowAlignment: ArrowAlignment = .leading
    ) {
        self.message = message
        self.position = position
        self.arrowAlignment = arrowAlignment
    }

    // MARK: - Body

    public var body: some View {
        WidthCappedHugLayout(maxWidth: maxWidth) {
            Text(message)
                .challaFont(.description.large.medium)
                .foregroundStyle(CHALLAColor.Label.normal)
                .padding(Metric.contentPadding)
                .frame(minWidth: Metric.bubbleMinWidth)
                .padding(Edge.Set(position.arrowEdge), TooltipShape.arrowArea)
        }
        .background {
            let shape = TooltipShape(position: position, arrowAlignment: arrowAlignment)
            shape
                // 시안의 background blur(radius 12)에 대응하는 SwiftUI 재질.
                .fill(CHALLAColor.Background.level2.opacity(Metric.backgroundOpacity))
                .background(.ultraThinMaterial, in: shape)
        }
    }

    /// 뷰 전체 최대 폭. 좌우로 화살표 영역이 붙는 방향에서는 그만큼 더한다.
    private var maxWidth: CGFloat {
        let bubbleMaxWidth = Metric.contentMaxWidth + Metric.contentPadding * 2
        switch position {
        case .top, .bottom: return bubbleMaxWidth
        case .leading, .trailing: return bubbleMaxWidth + TooltipShape.arrowArea
        }
    }
}

// MARK: - 폭 상한 감싸기

/// 내용 크기를 그대로 감싸되, 제안 폭이 상한을 넘으면 상한 폭에서 줄바꿈시키는 컨테이너.
/// `frame(maxWidth:)`는 내용이 작아도 상한까지 늘어나고, `fixedSize`로 이를 막으면
/// 측정과 배치의 제안 폭이 어긋나 여러 줄 글자가 배경 밖으로 넘친다 —
/// 측정·배치에 같은 제안을 쓰는 Layout으로만 두 동작을 함께 얻을 수 있다.
private struct WidthCappedHugLayout: Layout {

    let maxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        return content.sizeThatFits(cappedProposal(proposal))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: cappedProposal(proposal))
    }

    private func cappedProposal(_ proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(width: min(proposal.width ?? maxWidth, maxWidth), height: proposal.height)
    }
}

// MARK: - 툴팁 모양

/// 말풍선 몸통(둥근 사각형)과 화살표를 한 패스로 합친 모양.
/// 배경이 77% 반투명이라 두 조각을 따로 칠하면 맞닿는 자리가 진해지거나 실금이 생긴다 —
/// union으로 합쳐 한 번에 칠한다.
struct TooltipShape: Shape {

    let position: CHALLATooltip.Position
    let arrowAlignment: CHALLATooltip.ArrowAlignment

    /// 화살표에 내주는 두께. 실제 돌출(약 6)에 앵커 쪽 숨 여백 2를 더한 Figma 컨테이너 값.
    static let arrowArea: CGFloat = 8
    /// 화살표 밑변 폭.
    static let arrowWidth: CGFloat = 20
    /// 모서리 끝에서 화살표 밑변까지의 안쪽 여백.
    static let arrowInset: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        let bubble = bubbleRect(in: rect)
        return Path(roundedRect: bubble, cornerRadius: CHALLARadius.medium)
            .union(arrowPath(bubble: bubble))
    }

    /// 전체 rect에서 화살표 영역을 뺀 말풍선 몸통 자리.
    func bubbleRect(in rect: CGRect) -> CGRect {
        var bubble = rect
        switch position.arrowEdge {
        case .top:
            bubble.origin.y += Self.arrowArea
            bubble.size.height -= Self.arrowArea
        case .bottom:
            bubble.size.height -= Self.arrowArea
        case .leading:
            bubble.origin.x += Self.arrowArea
            bubble.size.width -= Self.arrowArea
        case .trailing:
            bubble.size.width -= Self.arrowArea
        }
        return bubble
    }

    // MARK: 화살표

    private func arrowPath(bubble: CGRect) -> Path {
        Self.downArrow.applying(arrowTransform(bubble: bubble))
    }

    /// 아래 방향 기준 화살표를 화살표 모서리로 옮기는 변환.
    /// 좌우 모서리는 전치(x↔y)로 눕힌다 — 화살표가 좌우 대칭이라 뒤집혀도 모양이 같다.
    private func arrowTransform(bubble: CGRect) -> CGAffineTransform {
        switch position.arrowEdge {
        case .bottom:
            CGAffineTransform(
                a: 1, b: 0, c: 0, d: 1,
                tx: arrowOffset(from: bubble.minX, to: bubble.maxX), ty: bubble.maxY
            )
        case .top:
            CGAffineTransform(
                a: 1, b: 0, c: 0, d: -1,
                tx: arrowOffset(from: bubble.minX, to: bubble.maxX), ty: bubble.minY
            )
        case .trailing:
            CGAffineTransform(
                a: 0, b: 1, c: 1, d: 0,
                tx: bubble.maxX, ty: arrowOffset(from: bubble.minY, to: bubble.maxY)
            )
        case .leading:
            CGAffineTransform(
                a: 0, b: 1, c: -1, d: 0,
                tx: bubble.minX, ty: arrowOffset(from: bubble.minY, to: bubble.maxY)
            )
        }
    }

    /// 화살표 밑변 시작 좌표. 모서리 양 끝의 둥근 모퉁이(radius 10)를 피해 8 안쪽부터 붙는다.
    private func arrowOffset(from start: CGFloat, to end: CGFloat) -> CGFloat {
        switch arrowAlignment {
        case .leading: start + Self.arrowInset
        case .center: (start + end - Self.arrowWidth) / 2
        case .trailing: end - Self.arrowInset - Self.arrowWidth
        }
    }

    /// 아래를 가리키는 화살표 원형. Zeplin `Arrow Tip` 벡터(20×8 SVG)의 좌표를 그대로 옮겼다.
    /// 밑변(y=0)은 말풍선 몸통 모서리에 맞닿는 자리 — 안쪽으로 1pt 겹치게 늘려
    /// (union이 흡수) 맞닿는 경계의 안티앨리어싱 실금을 막는다.
    private static var downArrow: Path {
        var path = Path()
        path.move(to: CGPoint(x: 7.57038, y: 4.16544))
        path.addLine(to: CGPoint(x: 5.91566, y: 2.23494))
        path.addCurve(
            to: CGPoint(x: 4.43043, y: 0.706626),
            control1: CGPoint(x: 5.21105, y: 1.41289),
            control2: CGPoint(x: 4.85874, y: 1.00187)
        )
        path.addCurve(
            to: CGPoint(x: 3.18337, y: 0.133056),
            control1: CGPoint(x: 4.0509, y: 0.445007),
            control2: CGPoint(x: 3.629, y: 0.250961)
        )
        path.addCurve(
            to: CGPoint(x: 1.05642, y: 0),
            control1: CGPoint(x: 2.68047, y: 0),
            control2: CGPoint(x: 2.13912, y: 0)
        )
        path.addLine(to: CGPoint(x: 1.05642, y: -1))
        path.addLine(to: CGPoint(x: 18.9436, y: -1))
        path.addLine(to: CGPoint(x: 18.9436, y: 0))
        path.addCurve(
            to: CGPoint(x: 16.8166, y: 0.133056),
            control1: CGPoint(x: 17.8609, y: 0),
            control2: CGPoint(x: 17.3195, y: 0)
        )
        path.addCurve(
            to: CGPoint(x: 15.5696, y: 0.706626),
            control1: CGPoint(x: 16.371, y: 0.250961),
            control2: CGPoint(x: 15.9491, y: 0.445007)
        )
        path.addCurve(
            to: CGPoint(x: 14.0843, y: 2.23494),
            control1: CGPoint(x: 15.1413, y: 1.00186),
            control2: CGPoint(x: 14.789, y: 1.41289)
        )
        path.addLine(to: CGPoint(x: 12.4296, y: 4.16544))
        path.addCurve(
            to: CGPoint(x: 10.6761, y: 5.80906),
            control1: CGPoint(x: 11.5926, y: 5.14193),
            control2: CGPoint(x: 11.1741, y: 5.63017)
        )
        path.addCurve(
            to: CGPoint(x: 9.32386, y: 5.80906),
            control1: CGPoint(x: 10.2391, y: 5.96607),
            control2: CGPoint(x: 9.76095, y: 5.96607)
        )
        path.addCurve(
            to: CGPoint(x: 7.57038, y: 4.16544),
            control1: CGPoint(x: 8.82586, y: 5.63017),
            control2: CGPoint(x: 8.40737, y: 5.14193)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Figma 실측값

private enum Metric {
    static let contentPadding: CGFloat = 10
    static let bubbleMinWidth: CGFloat = 64
    /// 문구가 줄바꿈되는 내용 폭 한도 (Zeplin Content `maxWidth`).
    static let contentMaxWidth: CGFloat = 256
    static let backgroundOpacity: Double = 0.77
}

#Preview {
    VStack(spacing: 24) {
        CHALLATooltip("메시지에 마침표를 찍어요.")
        CHALLATooltip("메시지에 마침표를 찍어요.", position: .bottom, arrowAlignment: .center)
        CHALLATooltip("메시지에 마침표를 찍어요.", position: .leading)
        CHALLATooltip("메시지에 마침표를 찍어요.", position: .trailing, arrowAlignment: .trailing)
    }
    .padding(40)
    .background(CHALLAColor.Background.surface)
}
