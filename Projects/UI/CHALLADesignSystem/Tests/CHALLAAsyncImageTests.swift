@testable import CHALLADesignSystem
import CHALLAImageKit
import SwiftUI
import Testing

/// CHALLAAsyncImage의 순수 로직(상태 enum·Environment 키) 테스트.
/// 뷰 렌더링 자체는 검수앱 갤러리에서 눈으로 검수한다.
struct CHALLAAsyncImageTests {

    // MARK: - CHALLAAsyncImagePhase

    @Test("success 상태면 image가 있고 error는 nil이다")
    func successExposesImageOnly() {
        let phase = CHALLAAsyncImagePhase.success(Image(systemName: "photo"))

        #expect(phase.image != nil)
        #expect(phase.error == nil)
    }

    @Test("failure 상태면 error가 있고 image는 nil이다")
    func failureExposesErrorOnly() {
        let phase = CHALLAAsyncImagePhase.failure(ImageLoadingError.emptyData)

        #expect(phase.image == nil)
        #expect(phase.error as? ImageLoadingError == .emptyData)
    }

    @Test("empty 상태면 image·error 둘 다 nil이다")
    func emptyExposesNothing() {
        let phase = CHALLAAsyncImagePhase.empty

        #expect(phase.image == nil)
        #expect(phase.error == nil)
    }

    // MARK: - Environment 키

    @Test("주입이 없어도 기본 로더가 존재한다")
    func defaultLoaderExists() {
        let values = EnvironmentValues()

        #expect(values.challaImageLoader != nil)
    }

    @Test("기본 로더는 몇 번을 읽어도 같은 인스턴스다")
    func defaultLoaderIsSharedInstance() {
        // 수동 키의 static let이 "한 번 생성·공유"를 실제로 지키는지 확인한다.
        // (이 테스트가 있어야 나중에 @Entry 등으로 구현을 바꿀 때 공유가 깨지면 바로 잡힌다)
        let first = EnvironmentValues().challaImageLoader
        let second = EnvironmentValues().challaImageLoader

        #expect(first === second)
    }

    @Test("주입한 로더가 기본 로더를 대체한다")
    func injectedLoaderReplacesDefault() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CHALLAAsyncImageTests-\(UUID().uuidString)", isDirectory: true)
        let custom = try ImageLoader(configuration: ImageCacheConfiguration(
            memoryCostLimitBytes: 1024,
            diskDirectory: directory,
            diskCapacityBytes: 1024
        ))

        var values = EnvironmentValues()
        values.challaImageLoader = custom

        #expect(values.challaImageLoader === custom)
    }

    // MARK: - ImageLoadSize

    /// 소수점만 다른 두 측정값이 같은 크기가 되어야 한 장에 요청이 여러 번 나가지 않는다.
    @Test("배치 크기를 정수 pt로 올려 잡는다", arguments: [
        (CGSize(width: 82.33, height: 109.77), CGSize(width: 83, height: 110)),
        (CGSize(width: 82.67, height: 109.33), CGSize(width: 83, height: 110)),
        (CGSize(width: 30, height: 30), CGSize(width: 30, height: 30))
    ])
    func quantizesToWholePoints(input: CGSize, expected: CGSize) {
        #expect(ImageLoadSize.quantized(input) == expected)
    }

    @Test("같은 크기로 다시 요청하면 받지 않는다")
    func skipsReloadForSameSize() {
        let loaded = CGSize(width: 83, height: 110)

        #expect(ImageLoadSize.needsReload(loaded: loaded, requested: loaded) == false)
    }

    @Test("작아지면 받지 않는다 — 가진 이미지를 줄여 그린다")
    func skipsReloadWhenSmaller() {
        let loaded = CGSize(width: 83, height: 110)

        #expect(ImageLoadSize.needsReload(loaded: loaded, requested: CGSize(width: 40, height: 54)) == false)
    }

    @Test("가로·세로 중 하나라도 커지면 다시 받는다 — 작게 받은 이미지를 늘려 그리면 흐려진다", arguments: [
        CGSize(width: 84, height: 110),
        CGSize(width: 83, height: 111)
    ])
    func reloadsWhenLarger(requested: CGSize) {
        let loaded = CGSize(width: 83, height: 110)

        #expect(ImageLoadSize.needsReload(loaded: loaded, requested: requested))
    }
}
