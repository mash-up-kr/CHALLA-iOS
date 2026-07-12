@testable import CHALLADesignSystem
import Testing

/// 타이포 토큰의 불변식 검증.
/// Figma 시안 값이 코드에 잘못 옮겨졌을 때(크기·행간 뒤바뀜 등) 컴파일은 통과하므로 테스트로 잡는다.
struct CHALLAFontTests {

    /// Figma에 정의된 3굵기(WeightSet) 토큰 전체
    private let weightSets: [CHALLAFont.WeightSet] = [
        CHALLAFont.Heading.large, CHALLAFont.Heading.medium, CHALLAFont.Heading.small,
        CHALLAFont.Body.large, CHALLAFont.Body.medium, CHALLAFont.Body.small,
        CHALLAFont.Description.large, CHALLAFont.Description.medium, CHALLAFont.Description.small
    ]

    @Test("WeightSet의 세 굵기는 같은 크기·행간을 공유한다")
    func weightSetSharesMetrics() {
        for set in weightSets {
            #expect(set.bold.size == set.regular.size)
            #expect(set.medium.size == set.regular.size)
            #expect(set.bold.lineHeight == set.regular.lineHeight)
            #expect(set.medium.lineHeight == set.regular.lineHeight)
        }
    }

    @Test("WeightSet 토큰은 행간이 크기보다 작지 않다 — challaFont 행간 보정이 항상 0 이상")
    func lineHeightIsNotSmallerThanSize() {
        // Dirtyline 단일 토큰(Heading.xlarge)은 의도적으로 lineHeight < size 라 제외
        for set in weightSets {
            #expect(set.regular.lineHeight >= set.regular.size)
        }
    }

    @Test("모든 토큰의 크기는 양수다")
    func sizesArePositive() {
        for set in weightSets {
            #expect(set.regular.size > 0)
        }
        #expect(CHALLAFont.Heading.home.size > 0)
        #expect(CHALLAFont.Heading.xlarge.size > 0)
    }
}
