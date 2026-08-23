import SwiftUI

/// 메시지 입력창. 채팅(개별 상세)·사진 상세가 공용으로 쓴다 — placeholder만 다르고 UI는 동일하다.
///
/// - 안내 문구·입력 글자는 항상 왼쪽 정렬.
/// - 포커스/입력 상태: 라임 포커스 테두리와 전송 버튼을 띄운다.
///   전송 버튼은 박스 안에서 **자리를 차지**하므로(오버레이가 아니라 HStack) 긴 입력이 버튼 뒤로 가려지지 않는다.
///
/// 전송은 버튼 탭 또는 키보드 리턴(`.send`)으로 한다.
///
/// ```swift
/// CHALLAMessageInputBar(text: $draft, placeholder: "메시지를 보내 보세요.") { store.send(.sendTapped) }
/// ```
public struct CHALLAMessageInputBar: View {

    @Binding private var text: String
    private let placeholder: String
    private let onSend: () -> Void
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        onSend: @escaping () -> Void
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSend = onSend
    }

    /// 포커스됐거나 입력값이 있으면 전송 버튼을 띄우고 글자를 왼쪽 정렬한다 (시안의 focus/typing 상태).
    private var isActive: Bool {
        isFocused || !text.isEmpty
    }

    public var body: some View {
        HStack(spacing: Metric.gap) {
            inputText
            if isActive {
                sendButton
            }
        }
        .padding(.horizontal, Metric.horizontalPadding)
        // 높이를 고정한다 — 포커스 시 전송 버튼(32)이 나타나도 입력창 높이가 바뀌지 않아,
        // 이 높이를 참조하는 화면(사진 상세)이 재레이아웃되며 사진이 리사이즈되는 일이 없다.
        .frame(height: Metric.boxHeight)
        .background(CHALLAColor.Background.level2, in: RoundedRectangle(cornerRadius: Metric.radius))
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: Metric.radius)
                    .strokeBorder(CHALLAColor.defaultTheme, lineWidth: Metric.focusBorderWidth)
            }
        }
        .animation(.easeOut(duration: Metric.toggleDuration), value: isActive)
        .contentShape(RoundedRectangle(cornerRadius: Metric.radius))
        .onTapGesture { isFocused = true }
    }

    private var inputText: some View {
        ZStack(alignment: .leading) {
            // placeholder·입력 글자 모두 왼쪽 정렬.
            if text.isEmpty {
                Text(placeholder)
                    .challaFont(.body.medium.medium)
                    .foregroundStyle(CHALLAColor.Label.alternative)
            }
            TextField("", text: $text)
                .challaFont(.body.medium.medium)
                .foregroundStyle(CHALLAColor.Label.normal)
                .tint(CHALLAColor.defaultTheme)
                .multilineTextAlignment(.leading)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(onSend)
                .accessibilityLabel(placeholder)
        }
        .frame(maxWidth: .infinity)
    }

    /// 전송 버튼(시안 `iconButton / Primary / Small` 32×32 — 배경·화살표가 담긴 DS 에셋).
    private var sendButton: some View {
        Button(action: onSend) {
            Image("MessageSendButton", bundle: .module)
                .resizable()
                .frame(width: Metric.sendSize, height: Metric.sendSize)
        }
        .accessibilityLabel("보내기")
    }

    private enum Metric {
        static let gap: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        /// 입력창 고정 높이(시안 inputbox 52). 포커스로 전송 버튼이 나타나도 높이가 변하지 않게 한다.
        static let boxHeight: CGFloat = 52
        static let radius: CGFloat = 12
        static let focusBorderWidth: CGFloat = 1.5
        static let sendSize: CGFloat = 32
        static let toggleDuration: Double = 0.12
    }
}
