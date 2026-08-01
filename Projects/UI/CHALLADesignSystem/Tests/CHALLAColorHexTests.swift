@testable import CHALLADesignSystem
import SwiftUI
import Testing
import UIKit

/// `Color(hex:)` 파싱 검증. 모든 색 토큰이 이 init 하나를 지나므로,
/// 비트 시프트 자릿수가 뒤바뀌는 실수(R↔B 등)는 컴파일을 통과한 채
/// 전 토큰 색을 틀어뜨린다 — 성분 단위로 고정해 잡는다.
struct CHALLAColorHexTests {

    /// UIColor 변환 반올림 허용 오차 — hex 한 단계(1/255)보다 작게 잡는다
    private let tolerance: CGFloat = 0.001

    /// SwiftUI Color에는 성분 접근자가 없어 UIColor를 거쳐 sRGB 성분을 읽는다
    private func rgba(_ color: Color) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }

    @Test("'#' 접두사는 파싱 결과를 바꾸지 않는다")
    func hashPrefixIsIgnored() {
        #expect(Color(hex: "FF1887") == Color(hex: "#FF1887"))
    }

    @Test("6자리 hex가 자릿수 순서대로 R·G·B 성분이 된다 — 브랜드 핑크 FF1887")
    func parsesDigitsIntoComponents() {
        let components = rgba(Color(hex: "FF1887"))
        #expect(abs(components.red - 255.0 / 255.0) <= tolerance)
        #expect(abs(components.green - 24.0 / 255.0) <= tolerance)
        #expect(abs(components.blue - 135.0 / 255.0) <= tolerance)
        #expect(abs(components.alpha - 1.0) <= tolerance)
    }

    @Test("opacity 파라미터가 알파 성분으로 그대로 전달된다 — Line.normal 실측값")
    func opacityPassesThroughToAlpha() {
        let components = rgba(Color(hex: "818181", opacity: 0.22))
        #expect(abs(components.alpha - 0.22) <= tolerance)
    }

    @Test("hex가 아닌 문자열은 검정으로 떨어진다")
    func invalidStringFallsBackToBlack() {
        #expect(Color(hex: "GGGGGG") == CHALLAColor.Static.black)
    }
}
