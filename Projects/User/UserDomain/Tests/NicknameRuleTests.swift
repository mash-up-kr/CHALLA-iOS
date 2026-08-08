import Testing
import UserDomain

@Suite("NicknameRule")
struct NicknameRuleTests {

    private static let tenChars = "나는야멋쟁이토마토임" // 10자
    private static let elevenChars = tenChars + "다" // 11자

    @Test(
        "sanitize — 개행 외의 입력은 그대로 보존한다 (validate가 값을 실시간으로 판정할 수 있게)",
        arguments: ["챌라", tenChars, elevenChars, ""]
    )
    func sanitizePreservesInput(raw: String) {
        #expect(NicknameRule.sanitize(raw) == raw)
    }

    @Test(
        "sanitize — 개행만 제거한다 (한 줄 필드 · 붙여넣기 방어)",
        arguments: zip(["챌라\n최고", "챌\r라\r\n"], ["챌라최고", "챌라"])
    )
    func sanitizeRemovesNewlines(raw: String, expected: String) {
        #expect(NicknameRule.sanitize(raw) == expected)
    }

    @Test("validate — 이모지·결합 문자는 grapheme cluster 1자로 센다")
    func validateCountsGraphemeClusters() {
        let families = String(repeating: "👨‍👩‍👧‍👦", count: 10) // 유니코드 스칼라는 훨씬 많지만 10자다
        #expect(NicknameRule.validate(families) == nil)
        #expect(NicknameRule.validate(families + "👨‍👩‍👧‍👦") == .tooLong(limit: 10))
    }

    @Test("validate — 공백도 1자로 센다")
    func validateCountsWhitespaceAsCharacter() {
        #expect(NicknameRule.validate("챌라 좋아 정말최고") == nil) // 공백 2개 포함 10자
        #expect(NicknameRule.validate("챌라 좋아 정말최고다") == .tooLong(limit: 10)) // 11자
    }

    @Test("validate — 빈 문자열·공백만 입력은 .empty", arguments: ["", "   ", " \n "])
    func validateEmptyInput(value: String) {
        #expect(NicknameRule.validate(value) == .empty)
    }

    @Test("validate — 정상 값은 nil, 11자는 .tooLong(limit: 10)")
    func validateLength() {
        #expect(NicknameRule.validate("챌라") == nil)
        #expect(NicknameRule.validate(" 챌라 ") == nil)
        #expect(NicknameRule.validate(Self.tenChars) == nil)
        #expect(NicknameRule.validate(Self.elevenChars) == .tooLong(limit: 10))
    }

    @Test("normalized — 앞뒤 공백은 제거하고 내부 공백은 보존한다")
    func normalizedTrimsEdgesOnly() {
        #expect(NicknameRule.normalized("  챌라 최고  ") == "챌라 최고")
        #expect(NicknameRule.normalized("챌라") == "챌라")
    }

    @Test("Violation.userMessage 문구 회귀")
    func violationUserMessage() {
        #expect(
            NicknameRule.Violation.tooLong(limit: NicknameRule.maxLength).userMessage
                == "공백 포함 10자까지 입력할 수 있어요"
        )
        #expect(NicknameRule.Violation.empty.userMessage == "닉네임을 입력해 주세요.")
    }
}
