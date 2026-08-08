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
}
