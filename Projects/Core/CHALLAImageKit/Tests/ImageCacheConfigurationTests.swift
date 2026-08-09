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

    @Test("메모리 상한은 기기 총 메모리의 10%로 정해진다")
    func memoryLimitScalesWithPhysicalMemory() {
        let fourGigabytes: UInt64 = 4 * 1024 * 1024 * 1024

        let limit = ImageCacheConfiguration.defaultMemoryCostLimit(physicalMemoryBytes: fourGigabytes)

        // 4GB의 10% = 409.6MB
        #expect(limit / (1024 * 1024) == 409)
    }

    @Test("총 메모리가 작은 기기에서는 하한 없이 10%가 그대로 적용된다")
    func memoryLimitHasNoLowerBound() {
        let halfGigabyte: UInt64 = 512 * 1024 * 1024

        let limit = ImageCacheConfiguration.defaultMemoryCostLimit(physicalMemoryBytes: halfGigabyte)

        // 512MB의 10% = 51.2MB. 실기기(최소 3GB)에서는 발동하지 않는 구간이라 하한을 두지 않았다.
        #expect(limit / (1024 * 1024) == 51)
    }

    @Test("총 메모리가 큰 기기에서도 상한(512MB)을 넘지 않는다")
    func memoryLimitClampsToMaximum() {
        let sixteenGigabytes: UInt64 = 16 * 1024 * 1024 * 1024

        let limit = ImageCacheConfiguration.defaultMemoryCostLimit(physicalMemoryBytes: sixteenGigabytes)

        // 1.6GB가 아니라 상한이 적용된다
        #expect(limit == 512 * 1024 * 1024)
    }

    @Test("기본 설정의 메모리 상한은 512MB를 넘지 않는다")
    func defaultMemoryLimitStaysUnderMaximum() {
        // 시뮬레이터는 기기가 아니라 맥의 RAM을 보고하므로, 상한이 없으면 이 값이 GB 단위가 된다.
        let config = ImageCacheConfiguration.default

        #expect(config.memoryCostLimitBytes <= 512 * 1024 * 1024)
    }

    @Test("기본 보관 기간은 서버의 방 삭제 정책과 같은 30일이다")
    func defaultRetentionMatchesServerPolicy() {
        let config = ImageCacheConfiguration.default

        #expect(config.diskRetention == 30 * 24 * 60 * 60)
    }

    @Test("기본 설정의 디스크 경로는 Caches 아래 CHALLAImageCache 폴더를 가리킨다")
    func defaultUsesDedicatedDirectory() {
        let config = ImageCacheConfiguration.default

        #expect(config.diskDirectory.lastPathComponent == "CHALLAImageCache")
    }
}
