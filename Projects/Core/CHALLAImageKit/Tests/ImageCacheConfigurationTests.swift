@testable import CHALLAImageKit
import Foundation
import Testing

struct ImageCacheConfigurationTests {

    @Test("커스텀 생성자에 넣은 메모리·디스크 용량과 디렉터리가 그대로 보관된다")
    func storesCustomValues() {
        let dir = URL(fileURLWithPath: "/tmp/test-cache", isDirectory: true)
        let config = ImageCacheConfiguration(
            memoryCostLimitBytes: 1024,
            diskDirectory: dir,
            diskCapacityBytes: 2048
        )

        #expect(config.memoryCostLimitBytes == 1024)
        #expect(config.diskDirectory == dir)
        #expect(config.diskCapacityBytes == 2048)
    }

    @Test("기본 설정(.default)의 메모리·디스크 용량 상한이 0보다 크다")
    func defaultLimitsArePositive() {
        let config = ImageCacheConfiguration.default

        #expect(config.memoryCostLimitBytes > 0)
        #expect(config.diskCapacityBytes > 0)
    }

    @Test("기본 설정의 디스크 경로는 Caches 아래 CHALLAImageCache 폴더를 가리킨다")
    func defaultUsesDedicatedDirectory() {
        let config = ImageCacheConfiguration.default

        #expect(config.diskDirectory.lastPathComponent == "CHALLAImageCache")
    }
}
