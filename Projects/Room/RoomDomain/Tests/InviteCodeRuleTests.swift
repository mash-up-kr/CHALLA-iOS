import RoomDomain
import Testing

@Suite("InviteCodeRule")
struct InviteCodeRuleTests {

    @Test("앞뒤 공백·개행을 제거한다")
    func trimsWhitespace() {
        #expect(InviteCodeRule.trimmed("  1928121  ") == "1928121")
        #expect(InviteCodeRule.trimmed("\n1928121\t") == "1928121")
    }

    @Test("공백 외에는 입력값을 바꾸지 않는다")
    func keepsInputAsIs() {
        #expect(InviteCodeRule.trimmed("challa1") == "challa1")
        #expect(InviteCodeRule.trimmed("ChAlLa1") == "ChAlLa1")
        #expect(InviteCodeRule.trimmed(" a3f9k2 ") == "a3f9k2")
    }

    @Test("빈 문자열·공백만은 제출할 수 없다")
    func emptyIsNotSubmittable() {
        #expect(!InviteCodeRule.isSubmittable(""))
        #expect(!InviteCodeRule.isSubmittable("   "))
        #expect(InviteCodeRule.isSubmittable(" 1928121 "))
    }
}
