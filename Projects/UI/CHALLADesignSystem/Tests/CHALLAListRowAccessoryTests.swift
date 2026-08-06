@testable import CHALLADesignSystem
import Testing

/// 리스트 행 우측 요소 검증.
/// 뷰가 그려지는 모습은 검수앱 갤러리로 확인하고, 여기서는 케이스가 값을 잃지 않는지만 검증한다.
struct CHALLAListRowAccessoryTests {

    @Test("arrow는 값 없는 화살표다")
    func arrowHasNoValue() {
        guard case let .arrow(value) = CHALLAListRowAccessory.arrow else {
            Issue.record("arrow가 .arrow 케이스로 만들어지지 않았다")
            return
        }
        #expect(value == nil)
    }

    @Test("arrow(value:)는 전달한 값을 그대로 담는다")
    func arrowCarriesValue() {
        guard case let .arrow(value) = CHALLAListRowAccessory.arrow(value: "레몬에이드") else {
            Issue.record("arrow(value:)가 .arrow 케이스로 만들어지지 않았다")
            return
        }
        #expect(value == "레몬에이드")
    }

    @Test("check는 선택 여부를 그대로 담는다", arguments: [true, false])
    func checkCarriesSelection(isSelected: Bool) {
        guard case let .check(stored) = CHALLAListRowAccessory.check(isSelected: isSelected) else {
            Issue.record("check가 .check 케이스로 만들어지지 않았다")
            return
        }
        #expect(stored == isSelected)
    }

    @Test("empty는 우측 요소가 없는 케이스다")
    func emptyHasNoAccessory() {
        guard case .empty = CHALLAListRowAccessory.empty else {
            Issue.record("empty가 .empty 케이스로 만들어지지 않았다")
            return
        }
    }
}
