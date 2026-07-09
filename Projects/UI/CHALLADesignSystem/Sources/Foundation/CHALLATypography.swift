import SwiftUI

// MARK: - CHALLATypography (그릇)

/// 하나의 타이포 스타일 = 폰트(크기 포함) + 행간(lineHeight).
/// SwiftUI Font는 lineHeight를 담지 못하므로, 둘을 함께 들고 다니는 그릇을 만든다.
public struct CHALLATypography: Sendable {
    
    public let font: Font
    
    /// Figma 기준 줄 높이(pt). 폰트 크기와 별개로 지정된다.
    public let size: CGFloat
    
    /// 폰트 크기(pt). lineHeight - size 로 위아래 여백을 계산하기 위해 보관.
    public let lineHeight: CGFloat


    init(font: Font, size: CGFloat, lineHeight: CGFloat) {
        self.font = font
        self.size = size
        self.lineHeight = lineHeight
    }
}

// MARK: - 적용 modifier

public extension View {
    
    /// CHALLATypography 토큰을 적용한다. 폰트 + 행간(lineSpacing/padding 보정)을 함께 반영.
    /// 사용 예시:
    /// ```swift
    /// Text("안녕하세요").challaFont(CHALLAFont.Body.mediumRegular)
    /// ```
    func challaFont(_ typography: CHALLATypography) -> some View {
        // lineHeight가 size보다 작은 폰트(예: Dirtyline heading.xlarge)는 음수가 되므로 0으로 막는다.
        let extraLineSpace = max(0, typography.lineHeight - typography.size)
        return self
            .font(typography.font)
            // SwiftUI lineSpacing은 "줄 사이 간격"이라 (lineHeight - size)가 실제 추가 간격.
            .lineSpacing(extraLineSpace)
            // 첫 줄 위/아래로도 절반씩 여백을 줘 Figma의 줄 높이 박스를 재현.
            .padding(.vertical, extraLineSpace / 2)
    }
}
