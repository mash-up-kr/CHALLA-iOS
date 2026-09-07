@testable import CHALLAImageKit
import CoreGraphics
import Foundation
import Testing

struct VectorDrawingLoaderTests {

    private let url = URL(string: "https://example.com/cover-stickers/1.svg")!
    private let otherURL = URL(string: "https://example.com/cover-stickers/2.svg")!

    private func svgData(originX: CGFloat = 0) -> Data {
        Data(
            """
            <svg viewBox="0 0 100 100">
            <rect x="\(originX)" y="0" width="10" height="10"/>
            </svg>
            """.utf8
        )
    }

    // MARK: - 캐시

    @Test("두 번째 요청은 네트워크를 타지 않는다")
    func cacheHitSkipsNetwork() async throws {
        let fetcher = MockImageDataFetcher.ok(svgData())
        let loader = VectorDrawingLoader(fetcher: fetcher)

        let first = try await loader.drawing(from: url)
        let second = try await loader.drawing(from: url)

        #expect(first == second)
        #expect(fetcher.callCount == 1)
    }

    @Test("같은 URL 동시 요청은 한 번만 받아온다")
    func concurrentRequestsShareOneFetch() async throws {
        let fetcher = MockImageDataFetcher.ok(svgData(), delayNanoseconds: 50_000_000)
        let loader = VectorDrawingLoader(fetcher: fetcher)

        try await withThrowingTaskGroup(of: VectorDrawing.self) { group in
            for _ in 0 ..< 5 {
                group.addTask { try await loader.drawing(from: url) }
            }

            for try await drawing in group {
                #expect(drawing.subpaths.count == 1)
            }
        }

        #expect(fetcher.callCount == 1)
    }

    @Test("maxCount를 넘으면 오래된 항목부터 버린다")
    func evictsOldestBeyondMaxCount() async throws {
        let fetcher = MockImageDataFetcher { requested in
            let response = try MockImageDataFetcher.makeHTTPResponse(url: requested, statusCode: 200)
            return (
                Data(#"<svg viewBox="0 0 100 100"><rect width="10" height="10"/></svg>"#.utf8),
                response
            )
        }
        let loader = VectorDrawingLoader(fetcher: fetcher, maxCount: 1)

        _ = try await loader.drawing(from: url)
        _ = try await loader.drawing(from: otherURL)
        _ = try await loader.drawing(from: url)

        #expect(fetcher.callCount == 3)
    }

    // MARK: - 실패

    @Test("HTTP 실패는 상태 코드와 함께 전파한다")
    func propagatesHTTPFailure() async throws {
        let fetcher = MockImageDataFetcher { requested in
            let response = try MockImageDataFetcher.makeHTTPResponse(url: requested, statusCode: 404)
            return (Data(), response)
        }
        let loader = VectorDrawingLoader(fetcher: fetcher)

        await #expect(throws: ImageLoadingError.httpStatus(404)) {
            try await loader.drawing(from: url)
        }
    }

    @Test("빈 응답은 emptyData로 실패한다")
    func propagatesEmptyData() async throws {
        let loader = VectorDrawingLoader(fetcher: MockImageDataFetcher.ok(Data()))

        await #expect(throws: ImageLoadingError.emptyData) {
            try await loader.drawing(from: url)
        }
    }

    @Test("전송 실패는 networkFailed로 감싼다")
    func propagatesNetworkFailure() async throws {
        let fetcher = MockImageDataFetcher { _ in throw URLError(.notConnectedToInternet) }
        let loader = VectorDrawingLoader(fetcher: fetcher)

        await #expect(throws: ImageLoadingError.networkFailed(.notConnectedToInternet)) {
            try await loader.drawing(from: url)
        }
    }

    @Test("파싱 실패를 그대로 전파한다")
    func propagatesParsingFailure() async throws {
        let fetcher = MockImageDataFetcher.ok(Data(#"<svg fill="none"><rect width="10" height="10"/></svg>"#.utf8))
        let loader = VectorDrawingLoader(fetcher: fetcher)

        await #expect(throws: VectorDrawingError.missingSize) {
            try await loader.drawing(from: url)
        }
    }

    @Test("실패는 캐시하지 않아 다음 요청이 다시 시도한다")
    func doesNotCacheFailure() async {
        let fetcher = MockImageDataFetcher { _ in throw URLError(.timedOut) }
        let loader = VectorDrawingLoader(fetcher: fetcher)

        _ = try? await loader.drawing(from: url)
        _ = try? await loader.drawing(from: url)

        #expect(fetcher.callCount == 2)
    }
}
