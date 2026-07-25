import SwiftUI

/// 버튼 공통 배경 + 터치 영역 규칙. Text·Icon 버튼이 항상 같은 규칙을 따르도록 한 곳에 모은다.
///
/// 담고 있는 정책:
/// - transparent variant는 배경을 그리지 않는다 (비활성이어도)
/// - 터치는 그려진 픽셀이 아니라 프레임 전체가 반응한다
/// - HIG 최소 터치 타깃(44pt) 미달 크기는 히트 영역만 보이지 않게 확장한다
struct CHALLAButtonBackgroundModifier: ViewModifier {
    let variant: CHALLAButtonVariant
    let size: CHALLAButtonSize
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if let background = variant.backgroundColor(isEnabled: isEnabled) {
                    RoundedRectangle(cornerRadius: size.radius)
                        .fill(background)
                }
            }
            .contentShape(
                RoundedRectangle(cornerRadius: size.radius)
                    .inset(by: -size.touchAreaInset)
            )
    }
}

// 기능은 위 Modifier에 있고, 이 extension은 .modifier(...) 호출 대신
// 다른 수정자들처럼 .challaButtonBackground(...) 점 문법으로 쓰게 하는 통로다.
extension View {
    /// 버튼 배경과 터치 영역 규칙을 적용한다 (상세: CHALLAButtonBackgroundModifier).
    func challaButtonBackground(
        variant: CHALLAButtonVariant,
        size: CHALLAButtonSize,
        isEnabled: Bool
    ) -> some View {
        modifier(CHALLAButtonBackgroundModifier(variant: variant, size: size, isEnabled: isEnabled))
    }
}
