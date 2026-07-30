import SwiftUI

/// 드로어 버튼 한 자리의 내용. 드로어가 이 값을 받아 CHALLATextButton으로 그린다.
///
/// 뷰가 아니라 값인 이유: 버튼의 크기(large)·전체 폭·간격·최대 개수는 드로어가
/// 강제해야 하는 규칙이라, 호출부에는 "글자·색·활성 여부·동작"만 열어준다.
///
/// ```swift
/// CHALLADrawerAction("만들기", isEnabled: canCreate) { store.send(.createTapped) }
/// CHALLADrawerAction("프로필 사진 삭제", variant: .neutral, role: .destructive) { ... }
/// ```
public struct CHALLADrawerAction {
    let title: String
    let variant: CHALLAButtonVariant
    let role: CHALLAButtonRole?
    let isEnabled: Bool
    let action: () -> Void

    /// - Parameters:
    ///   - isEnabled: 드로어가 버튼을 대신 만들기 때문에 .disabled()를 직접 걸 수 없어
    ///     여기서 받는다 (예: "만들기" 버튼은 방 이름이 비어 있으면 비활성).
    public init(
        _ title: String,
        variant: CHALLAButtonVariant = .primary,
        role: CHALLAButtonRole? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.role = role
        self.isEnabled = isEnabled
        self.action = action
    }
}
