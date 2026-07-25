import SwiftUI

/// 디자인 시스템 텍스트필드.
/// Figma의 상태 5가지(placeholder/focus/typing/typed/disabled)를 별도 파라미터 없이
/// 입력값 유무 × 포커스 × 활성 여부 조합으로 자동 판별한다.
/// 비활성화는 SwiftUI 표준 `.disabled(_:)`로 제어한다 — 색은 자동으로 비활성 팔레트로 바뀐다.
///
/// ```swift
/// CHALLATextField(text: $roomName, placeholder: "방 이름 입력", textAlignment: .leading)
/// ```
public struct CHALLATextField: View {

    /// 부모가 건 `.disabled(_:)`가 환경에 기록한 활성 여부를 물려받는다.
    /// 입력 차단(SwiftUI 담당)과 비활성 색 적용(이 뷰 담당)이 항상 같은 상태를 보도록
    /// 별도 isDisabled 파라미터 대신 표준 환경값을 읽는다.
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    @Binding private var text: String
    private let placeholder: String
    private let textAlignment: TextAlignment
    private let typography: CHALLATypography
    private let borderColor: Color

    /// - Parameters:
    ///   - text: 입력값. 소유는 호출부가 한다.
    ///   - placeholder: 비어 있을 때 보여줄 안내 문구.
    ///   - textAlignment: 글자 정렬. Figma 컴포넌트 기본은 중앙, 실사용(방 만들기)은 왼쪽 오버라이드.
    ///   - typography: 글자 타이포 (Figma customize 속성).
    ///   - borderColor: 포커스 테두리 + 커서 색 (Figma customize 속성).
    public init(
        text: Binding<String>,
        placeholder: String,
        textAlignment: TextAlignment = .center,
        typography: CHALLATypography = .body.medium.medium,
        borderColor: Color = CHALLAColor.Primary.yellow
    ) {
        self._text = text
        self.placeholder = placeholder
        self.textAlignment = textAlignment
        self.typography = typography
        self.borderColor = borderColor
    }

    public var body: some View {
        TextField("", text: $text, prompt: prompt)
            .challaFont(typography)
            .multilineTextAlignment(textAlignment)
            .foregroundStyle(isEnabled ? CHALLAColor.Label.normal : CHALLAColor.Label.disabled)
            .tint(borderColor)
            .focused($isFocused)
            .padding(.horizontal, Metric.contentPadding)
            .frame(height: typography.lineHeight + Metric.contentPadding * 2)
            .background {
                RoundedRectangle(cornerRadius: CHALLARadius.large)
                    .fill(CHALLAColor.Background.level2)
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: CHALLARadius.large)
                        .strokeBorder(borderColor, lineWidth: Metric.focusBorderWidth)
                }
            }
            // 글자 영역 밖 패딩을 눌러도 포커스되도록 박스 전체를 탭 영역으로 만든다.
            .contentShape(RoundedRectangle(cornerRadius: CHALLARadius.large))
            .onTapGesture { isFocused = true }
    }

    /// placeholder 문구. 비활성 시엔 입력 글자와 같은 비활성 색으로 맞춘다
    /// (Figma에 비활성+빈칸 조합 스펙이 없어 typed 비활성 색을 따른다).
    private var prompt: Text {
        Text(placeholder)
            .foregroundStyle(
                isEnabled ? CHALLAColor.Label.alternative : CHALLAColor.Label.disabled
            )
    }
}

// MARK: - Figma 실측값

private enum Metric {
    /// inputbox 내부 패딩 (전방향 16).
    static let contentPadding: CGFloat = 16
    /// focus·typing 상태의 테두리 두께.
    static let focusBorderWidth: CGFloat = 1.5
}

#Preview {
    @Previewable @State var empty = ""
    @Previewable @State var typed = "텍스트"

    VStack(spacing: 16) {
        CHALLATextField(text: $empty, placeholder: "내용을 입력해 주세요.")
        CHALLATextField(text: $typed, placeholder: "내용을 입력해 주세요.")
        CHALLATextField(text: $typed, placeholder: "내용을 입력해 주세요.")
            .disabled(true)
        CHALLATextField(text: $empty, placeholder: "방 이름 입력", textAlignment: .leading)
    }
    .padding()
    .background(CHALLAColor.Background.surface)
}
