import CHALLADesignSystem
import RoomDomain
import SwiftUI

public extension RoomCoverColor {

    /// 서버가 준 hex를 그대로 칠한다 — 커버 색 팔레트는 서버가 정하므로 디자인 토큰에 매핑하지 않는다.
    /// 형식이 어긋난 값은 중립색으로 접어 화면이 깨지지 않게 한다.
    var color: Color {
        Self.parse(hex) ?? CHALLAColor.Label.neutral
    }

    private static func parse(_ hex: String) -> Color? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
