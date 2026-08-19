import SwiftUI

/// 화면 위에 떠서 알리는 배너(토스트·스낵바)의 공통 표면.
/// Figma의 `toast`·`snackbar` 컴포넌트가 배경·모서리·여백을 공유해서 한 곳에 묶는다.
enum CHALLAFloatingSurfaceMetric {
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 9
    static let backgroundOpacity: Double = 0.77
}

extension View {

    func challaFloatingSurface() -> some View {
        padding(.horizontal, CHALLAFloatingSurfaceMetric.horizontalPadding)
            .padding(.vertical, CHALLAFloatingSurfaceMetric.verticalPadding)
            .background {
                RoundedRectangle(cornerRadius: CHALLARadius.large)
                    .fill(CHALLAColor.Background.level1.opacity(CHALLAFloatingSurfaceMetric.backgroundOpacity))
            }
    }
}
