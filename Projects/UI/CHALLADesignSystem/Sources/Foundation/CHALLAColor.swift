import SwiftUI

/// CHALLA 디자인 시스템의 색상 토큰.
/// Figma Theme의 색상 구조를 그대로 반영한다 (그룹 → 색상).
public enum CHALLAColor {

    /// Primary 팔레트 (브랜드 메인 색상)
    public enum Primary {
        public static let pink = Color(hex: "FF1887")
        public static let orange = Color(hex: "FF4D01")
        public static let yellow = Color(hex: "D5F700")
        public static let sky = Color(hex: "10E6D8")
        public static let blue = Color(hex: "508EFF")
        public static let purple = Color(hex: "C67AFF")
    }

    /// Label 팔레트 (텍스트/아이콘 색상, 강조 → 비활성 순)
    public enum Label {
        public static let strong = Color(hex: "FFFFFF")
        public static let normal = Color(hex: "F7F7F8")
        public static let subtle = Color(hex: "CCCDD4")
        public static let neutral = Color(hex: "AEAFB4")
        public static let alternative = Color(hex: "74767B")
        public static let disabled = Color(hex: "444549")
    }

    /// Background 팔레트 (표면/레이어 배경, 낮음 → 높음 순)
    public enum Background {
        public static let surface = Color(hex: "1A1A1A")
        public static let level1 = Color(hex: "1F1F1F")
        public static let level2 = Color(hex: "242424")
        public static let level3 = Color(hex: "2F2F2F")
        public static let level4 = Color(hex: "3B3B3B")
    }

    /// Line 팔레트 (구분선, 반투명)
    public enum Line {
        public static let normal = Color(hex: "818181", opacity: 0.22)
        public static let neutral = Color(hex: "7E7E7E", opacity: 0.16)
        public static let alternative = Color(hex: "7E7E7E", opacity: 0.08)
    }

    /// Static 팔레트 (테마와 무관하게 고정)
    public enum Static {
        public static let white = Color(hex: "FFFFFF")
        public static let black = Color(hex: "000000")
    }

    /// Material 팔레트 (모달 뒤 딤 처리 등, 반투명)
    public enum Material {
        public static let dimmer = Color(hex: "171719", opacity: 0.52)
    }

    /// Status 팔레트 (상태 피드백: 성공/주의/위험)
    public enum Status {
        public static let positive = Color(hex: "00E467")
        public static let cautionary = Color(hex: "FFB200")
        public static let destructive = Color(hex: "ED4C4C")
    }
}

// MARK: - Color(hex:)

extension Color {
    /// "FF1887" 또는 "#FF1887" 형태의 6자리 hex 문자열로 Color를 생성한다.
    /// - opacity: 불투명도(0~1). 생략 시 1.0(완전 불투명). Line/Dimmer 등 반투명 토큰에서만 지정한다.
    /// hex 파싱에 실패하면 rgb가 0으로 남아 검은색(#000000)이 된다.
    init(hex: String, opacity: Double = 1.0) {
        let sanitized = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
}
