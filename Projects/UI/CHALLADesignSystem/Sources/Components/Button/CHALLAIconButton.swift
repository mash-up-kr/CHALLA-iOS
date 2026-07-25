import SwiftUI

/// 디자인 시스템 아이콘 버튼. 아이콘 하나만 담는 정사각형 버튼이다.
/// 비활성화는 SwiftUI 표준 `.disabled(_:)`로 제어한다.
///
/// ```swift
/// CHALLAIconButton(.close, accessibilityLabel: "닫기", variant: .transparent) {
///     store.send(.closeTapped)
/// }
/// ```
public struct CHALLAIconButton: View {

    /// 부모가 건 `.disabled(_:)`가 환경에 기록한 활성 여부를 물려받는다.
    /// 터치 차단(SwiftUI 담당)과 비활성 색 적용(이 뷰 담당)이 항상 같은 상태를 보도록
    /// 별도 isDisabled 파라미터 대신 표준 환경값을 읽는다.
    @Environment(\.isEnabled) private var isEnabled

    private let icon: CHALLAIcon
    private let accessibilityLabel: String
    private let variant: CHALLAButtonVariant
    private let size: CHALLAButtonSize
    private let action: () -> Void

    /// - Parameters:
    ///   - accessibilityLabel: VoiceOver가 읽을 한국어 라벨 (예: "닫기").
    ///     글자가 없는 버튼이라 필수 — 없으면 에셋 이름("Close")이 영문으로 낭독된다.
    public init(
        _ icon: CHALLAIcon,
        accessibilityLabel: String,
        variant: CHALLAButtonVariant = .neutral,
        size: CHALLAButtonSize = .large,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.variant = variant
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            icon.image(size: size.iconSize, color: variant.contentColor(isEnabled: isEnabled))
                .frame(width: size.height, height: size.height)
                .background {
                    if let background = variant.backgroundColor(isEnabled: isEnabled) {
                        RoundedRectangle(cornerRadius: size.radius)
                            .fill(background)
                    }
                }
                // 탭 영역 정의: transparent(배경 없음)도 프레임 전체가 반응하고,
                // 44pt 미만 크기는 보이지 않게 사방으로 확장한다 (touchAreaInset 참고).
                .contentShape(
                    RoundedRectangle(cornerRadius: size.radius)
                        .inset(by: -size.touchAreaInset)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            CHALLAIconButton(.camera, accessibilityLabel: "촬영", variant: .primary) {}
            CHALLAIconButton(.setting, accessibilityLabel: "설정") {}
            CHALLAIconButton(.close, accessibilityLabel: "닫기", variant: .transparent) {}
        }
        HStack(spacing: 16) {
            CHALLAIconButton(.camera, accessibilityLabel: "촬영", variant: .primary, size: .medium) {}
            CHALLAIconButton(.setting, accessibilityLabel: "설정", size: .medium) {}
                .disabled(true)
            CHALLAIconButton(.close, accessibilityLabel: "닫기", variant: .transparent, size: .small) {}
        }
    }
    .padding()
    .background(CHALLAColor.Background.surface)
}
