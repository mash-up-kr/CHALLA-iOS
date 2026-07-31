@testable import CHALLADesignSystem
import Testing

/// 타이포 토큰의 불변식 검증.
/// 시안 값이 코드에 잘못 옮겨졌을 때(크기·행간 뒤바뀜 등) 컴파일은 통과하므로 테스트로 잡는다.
struct CHALLATypographyTests {

    /// 시안에 정의된 3굵기(WeightSet) 토큰 전체
    private let weightSets: [CHALLATypography.WeightSet] = [
        CHALLATypography.heading.large, CHALLATypography.heading.medium,
        CHALLATypography.heading.small, CHALLATypography.heading.xsmall,
        CHALLATypography.body.large, CHALLATypography.body.medium,
        CHALLATypography.body.small, CHALLATypography.body.xsmall,
        CHALLATypography.description.large, CHALLATypography.description.medium,
        CHALLATypography.description.small
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

    @Test("모든 토큰은 행간이 크기보다 작지 않다 — challaFont 행간 보정이 항상 0 이상")
    func lineHeightIsNotSmallerThanSize() {
        for set in weightSets {
            #expect(set.regular.lineHeight >= set.regular.size)
        }
        // Dirtyline 단일 토큰도 예외가 아니다 (시안: home 36/60, xlarge 60/60)
        for token in [CHALLATypography.heading.home, CHALLATypography.heading.xlarge] {
            #expect(token.lineHeight >= token.size)
        }
    }

    @Test("모든 토큰의 크기는 양수다")
    func sizesArePositive() {
        for set in weightSets {
            #expect(set.regular.size > 0)
        }
        #expect(CHALLATypography.heading.home.size > 0)
        #expect(CHALLATypography.heading.xlarge.size > 0)
    }

    @Test("lineBoxInset은 시안 행간과 크기 차이의 절반이다")
    func lineBoxInsetMatchesChallaFontPadding() {
        // challaFont는 (lineHeight - size)를 lineSpacing으로 주고, 그 절반씩을 위아래 패딩으로 넣는다.
        // 리스트 행·섹션 헤더가 시안 간격에서 이 값을 빼서 보정하므로, 어긋나면 레이아웃이 조용히 밀린다.
        #expect(CHALLATypography.body.medium.medium.lineBoxInset == 2) // 16/20
        #expect(CHALLATypography.body.xsmall.bold.lineBoxInset == 1) // 14/16
        #expect(CHALLATypography.body.large.regular.lineBoxInset == 3) // 18/24
        #expect(CHALLATypography.heading.large.bold.lineBoxInset == 4) // 28/36
        #expect(CHALLATypography.body.small.medium.lineBoxInset == 1.5) // 15/18
    }

    @Test("리스트가 전제하는 토큰 수치는 시안 그대로다")
    func listTypographyMatchesDesign() {
        // 행 높이(52·74)와 헤더 블록(44)이 이 수치를 전제로 계산된다 — 토큰이 바뀌면 레이아웃이 어긋난다.
        let title = CHALLATypography.body.medium.medium
        #expect(title.size == 16)
        #expect(title.lineHeight == 20)

        // 행 설명과 섹션 헤더는 같은 크기에 굵기만 다르다
        let description = CHALLATypography.body.xsmall.medium
        let header = CHALLATypography.body.xsmall.bold
        #expect(description.size == 14)
        #expect(description.lineHeight == 16)
        #expect(header.size == 14)
        #expect(header.lineHeight == 16)
    }
}
