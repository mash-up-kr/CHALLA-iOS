import SwiftUI

// MARK: - CHALLATypography

/// 타이포 토큰 하나의 스펙: 폰트 + 크기 + 줄 높이.
/// SwiftUI Font에는 줄 높이(lineHeight) 개념이 없어서 별도 타입으로 함께 관리한다.
public struct CHALLATypography: Sendable {

    public let font: Font

    /// 폰트 크기(pt). 행간 보정 계산에 필요해 Font와 별도로 보관한다.
    public let size: CGFloat

    /// Figma에 정의된 줄 높이(pt).
    public let lineHeight: CGFloat

    init(font: Font, size: CGFloat, lineHeight: CGFloat) {
        self.font = font
        self.size = size
        self.lineHeight = lineHeight
    }
}

// MARK: - View Modifier

public extension View {

    /// 타이포 토큰을 적용한다. 폰트와 함께 Figma의 줄 높이를 재현한다.
    ///
    /// ```swift
    /// Text("안녕하세요").challaFont(CHALLAFont.Body.medium.regular)
    /// ```
    func challaFont(_ typography: CHALLATypography) -> some View {
        // Figma 줄 높이와 폰트 크기의 차이만큼 여백을 만든다.
        // (lineHeight < size 인 Dirtyline 계열은 음수가 되므로 0으로 제한)
        let extraLineSpace = max(0, typography.lineHeight - typography.size)
        return self
            .font(typography.font)
            .lineSpacing(extraLineSpace)             // 줄 사이 간격
            .padding(.vertical, extraLineSpace / 2)  // 첫 줄 위 · 마지막 줄 아래 여백
    }
}
