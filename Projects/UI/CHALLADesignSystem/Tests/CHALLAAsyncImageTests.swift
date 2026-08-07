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
}
