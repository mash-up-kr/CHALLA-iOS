@testable import CHALLADesignSystem
import Testing

/// 프로필 바 넘침 칩 수량 규칙 검증.
/// 바에는 최대 9명까지만 표기하고, 넘치는 인원은 칩에 전체 - 9로 표시한다.
/// 방 상세 시안의 +4와 방 정원 10명이 맞지 않아 디자이너 확인 대기 중이므로,
/// 로직이 정원과 무관하게 일반화되어 있음을 함께 고정한다.
struct CHALLAProfileBarTests {

    @Test("전체 인원이 표기 한도 이하면 넘침 칩이 없다", arguments: [0, 1, 9])
    func noOverflowWithinLimit(totalMemberCount: Int) {
        #expect(CHALLAProfileBar.overflowCount(totalMemberCount: totalMemberCount) == nil)
    }

    // 10명은 경계 직후, 13명은 방 상세 시안 검산값(+4), 100명은 정원 무관 일반화 확인용이다.
    @Test("표기 한도를 넘으면 칩 수는 전체 - 9다", arguments: zip([10, 13, 100], [1, 4, 91]))
    func overflowBeyondLimit(totalMemberCount: Int, expected: Int) {
        #expect(CHALLAProfileBar.overflowCount(totalMemberCount: totalMemberCount) == expected)
    }
}
