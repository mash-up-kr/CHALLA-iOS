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

    /// 사용자가 설정에서 고르는 테마 색.
    /// 강조 요소(리스트 값 글자·스위치 켜짐 배경·텍스트필드 포커스 테두리)가 이 색을 따른다.
    ///
    /// 테마 6종은 `Primary` 팔레트와 1:1이다 —
    /// 레몬에이드=yellow · 라즈베리=pink · 오렌지=orange · 사이다=sky · 블루베리=blue · 아사이볼=purple.
    /// 테마를 고르기 전 기본값은 시안의 첫 테마인 레몬에이드다.
    ///
    /// 테마 시스템(사용자 선택값을 앱 전역에 전달)이 생기기 전까지는
    /// 컴포넌트가 이 값을 기본값으로 쓰고, 호출부가 필요할 때 덮어쓴다.
    public static let defaultTheme = Primary.yellow

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
        public static let surface = Color(hex: "111111")
        public static let level1 = Color(hex: "1F1F1F")
        public static let level2 = Color(hex: "242424")
        public static let level3 = Color(hex: "2F2F2F")
        public static let level4 = Color(hex: "3B3B3B")
    }

    /// Status 팔레트 (상태 피드백: 성공/주의/위험)
    public enum Status {
        public static let positive = Color(hex: "00E467")
        public static let cautionary = Color(hex: "FFB200")
        public static let destructive = Color(hex: "ED4C4C")
    }

    /// Fill 팔레트 (채움 요소)
    public enum Fill {
        /// 드로어 상단의 손잡이 막대 — "끌어서 닫을 수 있음" 표시 (Figma: Fill/60)
        public static let drawerHandle = Color(hex: "6C6F81")
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

    /// Social 팔레트 (소셜 로그인 버튼 브랜드 색)
    public enum Social {
        public static let kakao = Color(hex: "FEE503") // 카카오 버튼 배경(신규 원시값)
        public static let kakaoLabel = Static.black // 카카오 텍스트/아이콘(= #000000)
        public static let apple = Label.normal // 애플 버튼 배경(= #F7F7F8, 기존 재사용)
        public static let appleLabel = Static.black // 애플 텍스트/아이콘
    }
}

// MARK: - Color(hex:)

extension Color {
    /// "FF1887" 또는 "#FF1887" 형태의 6자리 hex 문자열로 Color를 생성한다.
    /// hex 파싱에 실패하면 rgb가 0으로 남아 검은색(#000000)이 된다.
    /// - Parameters:
    ///   - hex: 6자리 hex 문자열 ("#" 접두사 허용).
    ///   - opacity: 불투명도(0~1). 반투명 토큰에서만 지정한다.
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
