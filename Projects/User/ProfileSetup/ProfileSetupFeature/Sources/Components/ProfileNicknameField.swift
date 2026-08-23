import CHALLADesignSystem
import SwiftUI

/// 닉네임 입력 필드. 모드에 따라 테두리 색과 입력 가능 여부만 바꾼다 — 검증 판단은 리듀서 책임.
struct ProfileNicknameField: View {

    @Environment(\.challaTheme) private var theme

    @Binding var nickname: String
    var focus: FocusState<Bool>.Binding
    let mode: ProfileNicknameFieldMode

    var body: some View {
        CHALLATextField(
            text: $nickname,
            placeholder: "닉네임 입력",
            // 정상 상태는 넘기지 않는다 — 텍스트필드가 적용된 테마를 스스로 따른다.
            borderColor: mode == .invalid ? CHALLAColor.Status.destructive : nil,
            focus: focus
        )
        // .disabled는 텍스트를 비활성 색으로 흐리게 만든다 — 시안(d237/b5fc)의 읽기전용 닉네임은 정상 색이다.
        .allowsHitTesting(mode != .readOnly)
        .accessibilityLabel("닉네임")
    }
}

#Preview {
    @Previewable @State var nickname = "나는야멋쟁이토마토"
    @Previewable @FocusState var focus: Bool

    VStack(spacing: 16) {
        ProfileNicknameField(nickname: $nickname, focus: $focus, mode: .editable)
        ProfileNicknameField(nickname: $nickname, focus: $focus, mode: .invalid)
        ProfileNicknameField(nickname: $nickname, focus: $focus, mode: .readOnly)
    }
    .padding(24)
    .background(CHALLAColor.Background.level1)
}
