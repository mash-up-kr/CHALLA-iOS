@testable import CHALLADesignSystem
import Testing

/// 인화 카드 더보기 배지 수량 규칙 검증.
/// 슬롯이 4칸이라 넘칠 때는 "사진 3칸 + 더보기 1칸"이 되므로,
/// 배지 수는 전체 - 4가 아니라 전체 - 3이다. off-by-one이 나기 쉬워 경계마다 고정한다.
struct CHALLAPrintCardTests {

    @Test("전체 장수가 슬롯 수 이하면 더보기 배지가 없다", arguments: [0, 1, 4])
    func noOverflowWithinSlots(totalPhotoCount: Int) {
        #expect(CHALLAPrintCard.overflowCount(totalPhotoCount: totalPhotoCount) == nil)
    }

    // 5장은 경계 직후, 24장은 홈 시안 검산값(+21)이다.
    @Test("슬롯 수를 넘으면 배지 수는 전체 - 3이다", arguments: zip([5, 24], [2, 21]))
    func overflowBeyondSlots(totalPhotoCount: Int, expected: Int) {
        #expect(CHALLAPrintCard.overflowCount(totalPhotoCount: totalPhotoCount) == expected)
    }
}
