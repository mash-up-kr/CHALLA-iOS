import RoomDomain
import Testing

@Suite("RoomNameRule")
struct RoomNameRuleTests {

    @Test("20자 경계 — 19·20자는 그대로, 21자는 20자로 잘린다")
    func lengthBoundary() {
        let nineteen = String(repeating: "a", count: 19)
        let twenty = String(repeating: "a", count: 20)
        let twentyOne = String(repeating: "a", count: 21)

        #expect(RoomNameRule.truncated(nineteen) == nineteen)
        #expect(RoomNameRule.truncated(twenty) == twenty)
        #expect(RoomNameRule.truncated(twentyOne) == twenty)
    }

    @Test("한글도 한 글자 = 1로 센다")
    func koreanCountsPerCharacter() {
        let name = String(repeating: "가", count: 25)

        #expect(RoomNameRule.truncated(name) == String(repeating: "가", count: 20))
    }

    @Test("조합 이모지도 Character 단위로 한 글자다")
    func emojiCountsPerCharacter() {
        let family = "👨‍👩‍👧‍👦" // 스칼라 여러 개가 조합된 이모지 — Character로는 1
        let name = String(repeating: family, count: 21)

        let truncatedName = RoomNameRule.truncated(name)

        #expect(truncatedName.count == 20)
        #expect(truncatedName == String(repeating: family, count: 20))
    }

    @Test("trimmed는 앞뒤 공백만 떼고 사이 공백은 남긴다")
    func trimmedKeepsInnerSpaces() {
        #expect(RoomNameRule.trimmed("  제주 여행  ") == "제주 여행")
        #expect(RoomNameRule.trimmed("\n찰나\t") == "찰나")
        #expect(RoomNameRule.trimmed("친구들과 강릉 여행") == "친구들과 강릉 여행")
    }

    @Test("공백·개행만 입력한 이름은 제출할 수 없다")
    func whitespaceOnlyIsNotSubmittable() {
        #expect(!RoomNameRule.isSubmittable(""))
        #expect(!RoomNameRule.isSubmittable("   "))
        #expect(!RoomNameRule.isSubmittable(" \n\t "))
        #expect(RoomNameRule.isSubmittable(" 찰나 "))
    }

    @Test("공백 21자는 잘려도 제출할 수 없다")
    func truncatedWhitespaceStaysUnsubmittable() {
        let truncatedName = RoomNameRule.truncated(String(repeating: " ", count: 21))

        #expect(truncatedName.count == RoomNameRule.maxLength)
        #expect(!RoomNameRule.isSubmittable(truncatedName))
    }
}
