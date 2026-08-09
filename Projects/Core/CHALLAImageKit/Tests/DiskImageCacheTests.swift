@testable import CHALLAImageKit
import Foundation
import Testing

struct DiskImageCacheTests {

    private let url = URL(string: "https://example.com/photo.jpg")!
    private let otherURL = URL(string: "https://example.com/other.jpg")!
    private let size300 = PixelSize(width: 300, height: 300)
    private let size1200 = PixelSize(width: 1200, height: 1200)

    /// 테스트마다 고유한 임시 디렉터리를 만들어 서로 격리한다.
    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskImageCacheTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeCache(capacityBytes: Int = 10 * 1024 * 1024) throws -> DiskImageCache {
        try DiskImageCache(directory: makeTempDirectory(), capacityBytes: capacityBytes)
    }

    /// 방출 순서를 검증하려면 항목을 서로 구분해야 하므로, URL만 다른 키를 만든다.
    private func makeKey(_ name: String) -> ImageCacheKey {
        ImageCacheKey(url: url.appendingPathComponent(name), pixelSize: size300)
    }

    @Test("저장한 바이트는 같은 키로 조회하면 그대로 나온다")
    func returnsStoredData() async throws {
        let cache = try makeCache()
        let key = ImageCacheKey(url: url, pixelSize: size300)
        let data = Data("hello".utf8)

        await cache.store(data, for: key)

        #expect(await cache.data(for: key) == data)
    }

    @Test("저장하지 않은 키를 조회하면 nil이다")
    func returnsNilForMissingKey() async throws {
        let cache = try makeCache()
        let key = ImageCacheKey(url: url, pixelSize: size300)

        #expect(await cache.data(for: key) == nil)
    }

    @Test("같은 URL이라도 크기가 다르면 별도 파일로 취급한다")
    func distinguishesBySize() async throws {
        let cache = try makeCache()
        let gridKey = ImageCacheKey(url: url, pixelSize: size300)
        let detailKey = ImageCacheKey(url: url, pixelSize: size1200)

        await cache.store(Data("grid".utf8), for: gridKey)

        #expect(await cache.data(for: gridKey) != nil)
        #expect(await cache.data(for: detailKey) == nil)
    }

    @Test("removeAll 후에는 조회하면 nil이고 총량이 0이다")
    func removeAllClearsCache() async throws {
        let cache = try makeCache()
        let key = ImageCacheKey(url: url, pixelSize: size300)
        await cache.store(Data("hello".utf8), for: key)

        await cache.removeAll()

        #expect(await cache.data(for: key) == nil)
        #expect(await cache.totalBytes() == 0)
    }

    @Test("totalBytes는 저장한 바이트 수를 반영한다")
    func totalBytesReflectsStoredData() async throws {
        let cache = try makeCache()
        let data = Data(count: 500)

        await cache.store(data, for: ImageCacheKey(url: url, pixelSize: size300))
        await cache.store(data, for: ImageCacheKey(url: otherURL, pixelSize: size300))

        #expect(await cache.totalBytes() == 1000)
    }

    @Test("용량 초과 시 가장 오래된 파일부터 삭제한다(LRU)")
    func evictsOldestWhenOverCapacity() async throws {
        // 1000바이트 항목 3개는 3000바이트. 상한 2500이라 하나는 삭제되어야 한다.
        let cache = try makeCache(capacityBytes: 2500)
        let data = Data(count: 1000)
        let key1 = try ImageCacheKey(url: #require(URL(string: "https://example.com/1.jpg")), pixelSize: size300)
        let key2 = try ImageCacheKey(url: #require(URL(string: "https://example.com/2.jpg")), pixelSize: size300)
        let key3 = try ImageCacheKey(url: #require(URL(string: "https://example.com/3.jpg")), pixelSize: size300)

        // 수정일이 확실히 구분되도록 저장 사이에 짧은 간격을 둔다.
        await cache.store(data, for: key1)
        try await Task.sleep(nanoseconds: 20_000_000)
        await cache.store(data, for: key2)
        try await Task.sleep(nanoseconds: 20_000_000)
        await cache.store(data, for: key3)

        // 가장 오래된 key1이 삭제되고, 총량은 상한 이하로 유지된다.
        #expect(await cache.data(for: key1) == nil)
        #expect(await cache.data(for: key2) != nil)
        #expect(await cache.data(for: key3) != nil)
        #expect(await cache.totalBytes() <= 2500)
    }

    @Test("총량이 상한과 거리가 있으면 저장할 때마다 디렉터리를 읽지 않는다")
    func doesNotScanDirectoryOnEveryStore() async throws {
        // 상한 10MB에 1KB씩 5번 저장 — 상한 근처가 아니므로 스캔할 이유가 없다.
        let cache = try makeCache(capacityBytes: 10 * 1024 * 1024)
        let data = Data(count: 1024)

        for index in 0 ..< 5 {
            await cache.store(data, for: makeKey("scan-\(index)"))
        }

        // 실행 후 첫 저장에서 한 번만 읽어 총량을 파악하고, 그 뒤로는 추정치로 판단한다.
        #expect(await cache.directoryReadCount == 1)
    }

    @Test("방출은 상한이 아니라 방출 목표(상한의 90%)까지 지운다")
    func evictsDownToTarget() async throws {
        // 20만 바이트 3개는 60만. 상한 50만이라 목표 45만 이하가 될 때까지 지운다.
        let cache = try makeCache(capacityBytes: 500_000)
        let data = Data(count: 200_000)

        for index in 0 ..< 3 {
            await cache.store(data, for: makeKey("large-\(index)"))
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        // 상한(50만) 바로 아래에서 멈추지 않고 목표(45만)까지 내려간다.
        #expect(await cache.totalBytes() <= 450_000)
    }

    @Test("작은 이미지는 예약분 안에 있는 동안 큰 이미지에 밀려나지 않는다")
    func protectsSmallImagesWithinReserve() async throws {
        // 상한 50만 → 작은 이미지 예약분 5만. 2만 바이트 2개(총 4만)는 예약분 안이다.
        let cache = try makeCache(capacityBytes: 500_000)
        let smallData = Data(count: 20000)
        let largeData = Data(count: 200_000)

        // 작은 이미지를 먼저 저장한다 — 수정일로만 보면 가장 오래돼 제일 먼저 밀려날 자리다.
        for index in 0 ..< 2 {
            await cache.store(smallData, for: makeKey("small-\(index)"))
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        for index in 0 ..< 3 {
            await cache.store(largeData, for: makeKey("large-\(index)"))
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        // 더 오래됐는데도 작은 이미지는 남고, 큰 이미지 중 가장 오래된 것이 지워진다.
        #expect(await cache.data(for: makeKey("small-0")) != nil)
        #expect(await cache.data(for: makeKey("small-1")) != nil)
        #expect(await cache.data(for: makeKey("large-0")) == nil)
        #expect(await cache.data(for: makeKey("large-2")) != nil)
    }

    @Test("작은 이미지가 예약분을 넘으면 넘친 만큼은 오래된 것부터 방출된다")
    func evictsSmallImagesBeyondReserve() async throws {
        // 상한 50만 → 예약분 5만. 2만 바이트 4개(총 8만)는 예약분을 3만 넘긴다.
        let cache = try makeCache(capacityBytes: 500_000)
        let smallData = Data(count: 20000)
        let largeData = Data(count: 200_000)

        for index in 0 ..< 4 {
            await cache.store(smallData, for: makeKey("small-\(index)"))
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        for index in 0 ..< 3 {
            await cache.store(largeData, for: makeKey("large-\(index)"))
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        // 예약분은 최근 것부터 채우므로, 넘쳐서 후보가 되는 쪽은 가장 오래된 작은 이미지다.
        #expect(await cache.data(for: makeKey("small-0")) == nil)
        #expect(await cache.data(for: makeKey("small-2")) != nil)
        #expect(await cache.data(for: makeKey("small-3")) != nil)
    }
}
