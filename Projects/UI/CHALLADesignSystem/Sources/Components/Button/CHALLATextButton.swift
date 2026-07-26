import SwiftUI

/// 디자인 시스템 텍스트 버튼.
/// 비활성화는 SwiftUI 표준 `.disabled(_:)`로 제어한다 — 색은 자동으로 비활성 팔레트로 바뀐다.
///
/// ```swift
/// CHALLATextButton("촬영 시작") { store.send(.startTapped) }
///
/// CHALLATextButton("다음", variant: .neutral, size: .medium, trailingIcon: .caretRight) {
///     store.send(.nextTapped)
/// }
/// .disabled(!canProceed)
///
/// CHALLATextButton("그래도 탈퇴하기", role: .destructive) { store.send(.withdrawTapped) }
/// ```
public struct CHALLATextButton: View {

    /// 부모가 건 `.disabled(_:)`가 환경에 기록한 활성 여부를 물려받는다.
    /// 터치 차단(SwiftUI 담당)과 비활성 색 적용(이 뷰 담당)이 항상 같은 상태를 보도록
    /// 별도 isDisabled 파라미터 대신 표준 환경값을 읽는다.
    @Environment(\.isEnabled) private var isEnabled

    private let title: String
    private let variant: CHALLAButtonVariant
    private let role: CHALLAButtonRole?
    private let size: CHALLAButtonSize
    private let isFullWidth: Bool
    private let leadingIcon: CHALLAIcon?
    private let trailingIcon: CHALLAIcon?
    private let action: () -> Void

    public init(
        _ title: String,
        variant: CHALLAButtonVariant = .primary,
        role: CHALLAButtonRole? = nil,
        size: CHALLAButtonSize = .large,
        isFullWidth: Bool = false,
        leadingIcon: CHALLAIcon? = nil,
        trailingIcon: CHALLAIcon? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.role = role
        self.size = size
        self.isFullWidth = isFullWidth
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: size.contentSpacing) {
                if let leadingIcon {
                    leadingIcon.image(size: size.iconSize, color: contentColor)
                }
                Text(title)
                    .challaFont(size.typography)
                    .lineLimit(1)   // 고정 높이 안에서 줄바꿈되면 클리핑되므로 한 줄 고정
                if let trailingIcon {
                    trailingIcon.image(size: size.iconSize, color: contentColor)
                }
            }
            .foregroundStyle(contentColor)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            // 배경 모디파이어보다 앞에 있어야 배경·터치 영역이 함께 늘어난다
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .challaButtonBackground(variant: variant, role: role, size: size, isEnabled: isEnabled)
        }
        .buttonStyle(.plain)
    }

    private var contentColor: Color {
        variant.contentColor(role: role, isEnabled: isEnabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        CHALLATextButton("주요 버튼") {}
        CHALLATextButton("보통 버튼", variant: .neutral, trailingIcon: .caretRight) {}
        CHALLATextButton("투명 버튼", variant: .transparent) {}
        CHALLATextButton("비활성 버튼", size: .medium) {}
            .disabled(true)
        CHALLATextButton("작은 버튼", variant: .neutral, size: .small, leadingIcon: .check) {}
        CHALLATextButton("그래도 탈퇴하기", role: .destructive) {}
        CHALLATextButton("프로필 사진 삭제", variant: .neutral, role: .destructive) {}
    }
    .padding()
    .background(CHALLAColor.Background.surface)
}
