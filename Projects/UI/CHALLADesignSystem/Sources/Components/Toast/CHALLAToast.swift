import SwiftUI

/// 화면에 잠시 나타났다 사라지는 짧은 알림. 사용자가 수행한 작업에 대한 피드백을 준다.
///
/// 표시 시간과 배치는 담는 쪽 책임이다 — 이 뷰는 모양만 그린다.
/// 자동으로 사라지는 정보라 VoiceOver 사용자가 놓치지 않도록 등장·문구 교체 시 즉시 낭독한다.
///
/// ```swift
/// CHALLAToast("저장했어요")
/// CHALLAToast("사진을 불러오지 못했어요", icon: .error, variant: .negative)
/// ```
public struct CHALLAToast: View {

    /// 메시지 성격. 아이콘 색만 바꾼다.
    ///
    /// - TODO: 시안의 `positive`·`cautionary`는 아직 렌더된 적이 없어 색을 알 수 없다.
    ///   디자이너에게 문의해 둔 상태이며, 답변을 받으면 케이스를 추가한다.
    public enum Variant: Sendable {
        case normal
        case negative

        var iconColor: Color {
            switch self {
            case .normal: CHALLAColor.Label.subtle
            case .negative: CHALLAColor.Status.destructive
            }
        }
    }

    private let message: String
    private let icon: CHALLAIcon?
    private let variant: Variant

    /// - Parameter icon: nil이면 아이콘 없이 글자만 (시안의 `leadingIcon = false`).
    ///
    /// - TODO: 시안의 기본값은 `leadingIcon = true`지만 그 자리의 아이콘이 플레이스홀더라 그릴 자산이 없다.
    ///   그래서 지금은 아이콘 없음이 기본이다. 디자이너 답변을 받으면 기본값을 맞춘다.
    public init(_ message: String, icon: CHALLAIcon? = nil, variant: Variant = .normal) {
        self.message = message
        self.icon = icon
        self.variant = variant
    }

    public var body: some View {
        HStack(spacing: Metric.contentSpacing) {
            if let icon {
                icon.image(size: .size22, color: variant.iconColor)
            }
            Text(message)
                .challaFont(.body.small.medium)
                .foregroundStyle(CHALLAColor.Label.normal)
                .lineLimit(1)
        }
        .frame(minHeight: Metric.contentMinHeight)
        .padding(.horizontal, Metric.horizontalPadding)
        .padding(.vertical, Metric.verticalPadding)
        // 내용만큼만 넓어지고 한도에서 멈춘다 — maxWidth만 걸면 항상 한도까지 늘어난다.
        .frame(maxWidth: Metric.maxWidth)
        .fixedSize(horizontal: true, vertical: false)
        .background {
            RoundedRectangle(cornerRadius: CHALLARadius.large)
                // 시안의 background blur(radius 12)에 대응하는 SwiftUI 재질.
                .fill(CHALLAColor.Background.level1.opacity(Metric.backgroundOpacity))
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: CHALLARadius.large)
                )
        }
        .onAppear {
            AccessibilityNotification.Announcement(message).post()
        }
        // 토스트가 사라지지 않은 채 메시지만 교체되면 onAppear가 다시 불리지 않는다.
        .onChange(of: message) { _, newMessage in
            AccessibilityNotification.Announcement(newMessage).post()
        }
    }
}

// MARK: - Zeplin 실측값

private enum Metric {
    static let contentMinHeight: CGFloat = 32
    static let contentSpacing: CGFloat = 8
    static let maxWidth: CGFloat = 320

    /// 여백·배경 농도는 스낵바와 같은 표면 값을 쓴다 (`CHALLAFloatingSurface`).
    /// 배경에 재질을 한 겹 더 까는 것만 달라서 모디파이어 대신 상수만 공유한다.
    static let horizontalPadding = CHALLAFloatingSurfaceMetric.horizontalPadding
    static let verticalPadding = CHALLAFloatingSurfaceMetric.verticalPadding
    static let backgroundOpacity = CHALLAFloatingSurfaceMetric.backgroundOpacity
}

#Preview {
    VStack(spacing: 20) {
        CHALLAToast("마침표를 붙이지 않아요")
        CHALLAToast("마침표를 붙이지 않아요", icon: .error, variant: .negative)
    }
    .padding(40)
    .background(CHALLAColor.Background.surface)
}
