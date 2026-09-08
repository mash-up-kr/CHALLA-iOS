@testable import RoomCoverUI
import CHALLADesignSystem
import RoomDomain
import SwiftUI
import Testing

struct RoomCoverColorTests {

    @Test("hex는 # 유무·대소문자와 무관하게 같은 색이다", arguments: ["#FF1887", "FF1887", "ff1887"])
    func parsesHex(hex: String) {
        let color = RoomCoverColor(id: 1, name: "라즈베리", hex: hex).color
        #expect(color == Color(red: 255 / 255, green: 24 / 255, blue: 135 / 255))
    }

    @Test("형식이 어긋난 hex는 중립색으로 접는다", arguments: ["", "12345", "GGGGGG", "#FF18871"])
    func fallsBackOnMalformedHex(hex: String) {
        #expect(RoomCoverColor(id: 1, name: "?", hex: hex).color == CHALLAColor.Label.neutral)
    }
}
