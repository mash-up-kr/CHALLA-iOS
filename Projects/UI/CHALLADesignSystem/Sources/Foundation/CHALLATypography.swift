import SwiftUI

/// 타이포 토큰 하나의 스펙: 폰트 + 크기 + 줄 높이.
/// SwiftUI Font에는 줄 높이(lineHeight) 개념이 없어서 별도 타입으로 함께 관리한다.
public struct CHALLATypography: Sendable {

    public let font: Font

    /// 폰트 크기(pt). 행간 보정 계산에 필요해 Font와 별도로 보관한다.
    public let size: CGFloat

    /// Figma에 정의된 줄 높이(pt).
    public let lineHeight: CGFloat

    /// `challaFont(_:)`가 글자 상자 위아래에 각각 더하는 여백.
    ///
    /// 시안에 적힌 간격을 코드로 그대로 옮기면 이 여백만큼 벌어져 보인다.
    /// 시안 값에서 이 값을 빼야 화면에서 시안대로 나온다.
    ///
    /// ```swift
    /// // 시안 간격 6 → 실제로 6으로 보이게
    /// let spacing = 6 - CHALLATypography.body.medium.medium.lineBoxInset
    /// ```
    public var lineBoxInset: CGFloat {
        max(0, lineHeight - size) / 2
    }
}

// MARK: - challaFont

public extension View {

    /// 타이포 토큰을 적용한다. 폰트와 함께 Figma의 줄 높이를 재현한다.
    ///
    /// ```swift
    /// Text("안녕하세요").challaFont(.body.medium.regular)
    /// ```
    func challaFont(_ typography: CHALLATypography) -> some View {
        // 시안 줄 높이와 폰트 크기의 차이만큼 여백을 만든다.
        // max(0,)은 방어용 — 시안에는 lineHeight < size 인 토큰이 없다.
        // 음수가 나오면 토큰 값이 잘못 옮겨졌다는 뜻이므로 CHALLATypographyTests가 잡는다.
        let extraLineSpace = max(0, typography.lineHeight - typography.size)
        return self
            .font(typography.font)
            .lineSpacing(extraLineSpace) // 줄 사이 간격
            .padding(.vertical, extraLineSpace / 2) // 첫 줄 위 · 마지막 줄 아래 여백
    }
}
