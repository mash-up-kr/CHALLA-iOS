@testable import CHALLADesignSystem
import SwiftUI
import Testing

/// role 축 전수. destructive 외 케이스가 늘면 여기에 추가해 조합 테스트가 함께 넓어지게 한다.
private let allRoles: [CHALLAButtonRole?] = [nil, .destructive]

/// 버튼 variant × role 색 매핑 검증 (MODULE.md 백로그 "#8 이후 추가 예정" 항목).
/// 매핑이 튜플 switch라 가지를 잘못 짝지어도 컴파일은 통과하므로,
/// PR #20에서 확정된 규칙 — destructive는 primary만 빨간 채움, 나머지는 빨간 글자 — 를
/// 조합 전수로 고정한다. 토큰 static 값을 그대로 반환하므로 `==`로 직접 비교한다.
struct CHALLAButtonVariantTests {

    // MARK: - 활성 · role 없음

    @Test("활성 primary는 밝은 채움 + 어두운 글자다")
    func enabledPrimaryDefault() {
        #expect(CHALLAButtonVariant.primary.backgroundColor(isEnabled: true) == CHALLAColor.Label.normal)
        // 어두운 글자는 별도 토큰 없이 Label.disabled와 같은 값을 쓴다 (Figma 실측)
        #expect(CHALLAButtonVariant.primary.contentColor(isEnabled: true) == CHALLAColor.Label.disabled)
    }

    @Test("활성 neutral은 회색 채움 + 밝은 글자다")
    func enabledNeutralDefault() {
        #expect(CHALLAButtonVariant.neutral.backgroundColor(isEnabled: true) == CHALLAColor.Background.level3)
        #expect(CHALLAButtonVariant.neutral.contentColor(isEnabled: true) == CHALLAColor.Label.normal)
    }

    @Test("활성 transparent는 배경 없이 밝은 글자다")
    func enabledTransparentDefault() {
        #expect(CHALLAButtonVariant.transparent.backgroundColor(isEnabled: true) == nil)
        #expect(CHALLAButtonVariant.transparent.contentColor(isEnabled: true) == CHALLAColor.Label.normal)
    }

    // MARK: - 활성 · destructive

    @Test("destructive primary는 빨간 채움 + 밝은 글자다")
    func enabledDestructivePrimary() {
        #expect(
            CHALLAButtonVariant.primary.backgroundColor(role: .destructive, isEnabled: true)
                == CHALLAColor.Status.destructive
        )
        #expect(
            CHALLAButtonVariant.primary.contentColor(role: .destructive, isEnabled: true)
                == CHALLAColor.Label.normal
        )
    }

    @Test("destructive neutral·transparent는 빨간 글자다", arguments: [CHALLAButtonVariant.neutral, .transparent])
    func enabledDestructiveContentIsRed(variant: CHALLAButtonVariant) {
        #expect(
            variant.contentColor(role: .destructive, isEnabled: true)
                == CHALLAColor.Status.destructive
        )
    }

    @Test("destructive는 neutral의 회색 채움을 바꾸지 않는다")
    func enabledDestructiveKeepsNeutralBackground() {
        #expect(
            CHALLAButtonVariant.neutral.backgroundColor(role: .destructive, isEnabled: true)
                == CHALLAColor.Background.level3
        )
    }

    // MARK: - 비활성

    /// arguments 두 벌은 zip이 아니라 전수 조합(곱)이 의도다 — 이하 동일
    @Test(
        "비활성 primary·neutral 배경은 role과 무관하게 공통 비활성 팔레트다",
        arguments: [CHALLAButtonVariant.primary, .neutral], allRoles
    )
    func disabledBackgroundFallsToCommonPalette(variant: CHALLAButtonVariant, role: CHALLAButtonRole?) {
        #expect(variant.backgroundColor(role: role, isEnabled: false) == CHALLAColor.Background.level2)
    }

    @Test("비활성 글자색은 variant·role과 무관하게 disabled다", arguments: CHALLAButtonVariant.allCases, allRoles)
    func disabledContentIsAlwaysDisabled(variant: CHALLAButtonVariant, role: CHALLAButtonRole?) {
        #expect(variant.contentColor(role: role, isEnabled: false) == CHALLAColor.Label.disabled)
    }

    @Test("transparent는 role·활성 여부와 무관하게 배경이 없다", arguments: allRoles, [true, false])
    func transparentNeverHasBackground(role: CHALLAButtonRole?, isEnabled: Bool) {
        #expect(CHALLAButtonVariant.transparent.backgroundColor(role: role, isEnabled: isEnabled) == nil)
    }
}
