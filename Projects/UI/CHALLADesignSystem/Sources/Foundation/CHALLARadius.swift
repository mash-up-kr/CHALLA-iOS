import SwiftUI

/// CHALLA 디자인 시스템의 모서리 둥글기 토큰.
/// Figma에 radius 변수가 없어 버튼 컴포넌트 실측값을 기준으로 한다 (버튼 S/M/L = 8/10/12).
public enum CHALLARadius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 10
    public static let large: CGFloat = 12
    /// 프로필 바 멤버 팝오버 실측값.
    public static let xlarge: CGFloat = 16
}
