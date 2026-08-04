@testable import CHALLAImageKit
import Foundation
import Testing
import UIKit

struct ImageLoaderTests {

    private let url = URL(string: "https://example.com/photo.jpg")!
    private let pointSize = CGSize(width: 100, height: 100)
    private let scale: CGFloat = 1

    /// 테스트마다 고유한 임시 디스크 디렉터리를 써서 서로 격리한다.
    private func makeConfiguration() -> ImageCacheConfiguration {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageLoaderTests-\(UUID().uuidString)", isDirectory: true)
        return ImageCacheConfiguration(
            memoryCostLimitBytes: 100 * 1024 * 1024,
            diskDirectory: directory,
            diskCapacityBytes: 100 * 1024 * 1024
        )
    }

    /// 다운샘플이 성공하는 실제 JPEG 바이트.
    private func validJPEG() throws -> Data {
        try TestImageFactory.jpegData(pixelWidth: 400, pixelHeight: 400)
    }

    // MARK: - 조회 파이프라인

    @Test("메모리 히트: 두 번째 요청은 네트워크를 타지 않는다")
    func memoryHitSkipsNetwork() async throws {
        let fetcher = MockImageDataFetcher.ok(try validJPEG())
        let loader = try ImageLoader(configuration: makeConfiguration(), fetcher: fetcher)

        _ = try await loader.image(from: url, pointSize: pointSize, scale: scale)
        _ = try await loader.image(from: url, pointSize: pointSize, scale: scale)

        #expect(fetcher.callCount == 1)
    }

    @Test("디스크 히트: 새 로더도 네트워크 없이 디스크에서 가져온다")
    func diskHitSkipsNetwork() async throws {
        let configuration = makeConfiguration()

        // 1) 워밍 로더가 네트워크로 받아 디스크에 저장한다.
        let warmFetcher = MockImageDataFetcher.ok(try validJPEG())
        let warmLoader = try ImageLoader(configuration: configuration, fetcher: warmFetcher)
        _ = try await warmLoader.image(from: url, pointSize: pointSize, scale: scale)

        // 2) 같은 디스크를 쓰지만 호출 시 실패하는 페처 → 디스크 히트여야만 성공한다.
        let coldFetcher = MockImageDataFetcher { _ in throw URLError(.notConnectedToInternet) }
        let coldLoader = try ImageLoader(configuration: configuration, fetcher: coldFetcher)

        let image = try await coldLoader.image(from: url, pointSize: pointSize, scale: scale)

        #expect(image.size.width > 0)
        #expect(coldFetcher.callCount == 0)
    }

    @Test("네트워크 미스 후 다운샘플 바이트가 디스크에 저장된다")
    func storesToDiskAfterNetwork() async throws {
        let configuration = makeConfiguration()
        let fetcher = MockImageDataFetcher.ok(try validJPEG())
        let loader = try ImageLoader(configuration: configuration, fetcher: fetcher)

        _ = try await loader.image(from: url, pointSize: pointSize, scale: scale)

        let disk = try DiskImageCache(
            directory: configuration.diskDirectory,
            capacityBytes: configuration.diskCapacityBytes
        )
        let key = ImageCacheKey(url: url, pixelSize: PixelSize(pointSize: pointSize, scale: scale))
        #expect(await disk.data(for: key) != nil)
    }

    // MARK: - dedup

    @Test("dedup: 같은 키 동시 요청 시 네트워크는 한 번만 탄다")
    func deduplicatesConcurrentRequests() async throws {
        // 지연을 줘서 요청들이 확실히 겹치게 한다.
        let fetcher = MockImageDataFetcher.ok(try validJPEG(), delayNanoseconds: 50_000_000)
        let loader = try ImageLoader(configuration: makeConfiguration(), fetcher: fetcher)

        let url = url
        let pointSize = pointSize
        let scale = scale
        try await withThrowingTaskGroup(of: UIImage.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await loader.image(from: url, pointSize: pointSize, scale: scale)
                }
            }
            for try await _ in group {}
        }

        #expect(fetcher.callCount == 1)
    }

    // MARK: - 에러 매핑

    @Test("HTTPURLResponse가 아니면 invalidResponse")
    func nonHTTPResponseThrowsInvalidResponse() async throws {
        let fetcher = MockImageDataFetcher { url in
            let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data([0x01]), response)
        }
        let loader = try ImageLoader(configuration: makeConfiguration(), fetcher: fetcher)

        await #expect(throws: ImageLoadingError.invalidResponse) {
            try await loader.image(from: url, pointSize: pointSize, scale: scale)
        }
    }

    @Test("2xx가 아니면 httpStatus(코드)")
    func non2xxThrowsHTTPStatus() async throws {
        let fetcher = MockImageDataFetcher { url in
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (Data([0x01]), response)
        }
        let loader = try ImageLoader(configuration: makeConfiguration(), fetcher: fetcher)

        await #expect(throws: ImageLoadingError.httpStatus(404)) {
            try await loader.image(from: url, pointSize: pointSize, scale: scale)
        }
    }

    @Test("빈 데이터면 emptyData")
    func emptyDataThrows() async throws {
        let fetcher = MockImageDataFetcher.ok(Data())
        let loader = try ImageLoader(configuration: makeConfiguration(), fetcher: fetcher)

        await #expect(throws: ImageLoadingError.emptyData) {
            try await loader.image(from: url, pointSize: pointSize, scale: scale)
        }
    }

    @Test("이미지가 아닌 바이트면 downsampling(.invalidData)")
    func garbageThrowsDownsampling() async throws {
        let fetcher = MockImageDataFetcher.ok(Data("not an image".utf8))
        let loader = try ImageLoader(configuration: makeConfiguration(), fetcher: fetcher)

        await #expect(throws: ImageLoadingError.downsampling(.invalidData)) {
            try await loader.image(from: url, pointSize: pointSize, scale: scale)
        }
    }

    @Test("전송 실패면 networkFailed(코드)")
    func transportErrorThrowsNetworkFailed() async throws {
        let fetcher = MockImageDataFetcher { _ in throw URLError(.timedOut) }
        let loader = try ImageLoader(configuration: makeConfiguration(), fetcher: fetcher)

        await #expect(throws: ImageLoadingError.networkFailed(.timedOut)) {
            try await loader.image(from: url, pointSize: pointSize, scale: scale)
        }
    }

    // MARK: - removeAll

    @Test("removeAll 후에는 캐시가 비어 다시 네트워크를 탄다")
    func removeAllForcesRefetch() async throws {
        let fetcher = MockImageDataFetcher.ok(try validJPEG())
        let loader = try ImageLoader(configuration: makeConfiguration(), fetcher: fetcher)

        _ = try await loader.image(from: url, pointSize: pointSize, scale: scale)
        await loader.removeAll()
        _ = try await loader.image(from: url, pointSize: pointSize, scale: scale)

        #expect(fetcher.callCount == 2)
    }
}
