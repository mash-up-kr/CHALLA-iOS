@testable import CHALLAImageKit
import Foundation
import Testing

@Suite("ImageDataBatchDownloader")
struct ImageDataBatchDownloaderTests {

    // MARK: - 도우미

    private struct StubNetworkCondition: NetworkCondition {
        let isConstrained: Bool
    }

    /// 동시에 몇 개가 진행 중이었는지 기록한다.
    private actor ConcurrencyRecorder {
        private var current = 0
        private(set) var peak = 0

        func begin() {
            current += 1
            peak = max(peak, current)
        }

        func end() {
            current -= 1
        }
    }

    private static func urls(_ count: Int) -> [URL] {
        (0 ..< count).compactMap { URL(string: "https://example.com/\($0).jpg") }
    }

    private static func response(_ url: URL, status: Int = 200) -> URLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            ?? URLResponse()
    }

    /// URL 마지막 경로가 곧 그 장의 번호다 — 순서 검증에 쓴다.
    private static func index(of url: URL) -> Int {
        Int(url.deletingPathExtension().lastPathComponent) ?? -1
    }

    private static func collect(
        _ downloader: ImageDataBatchDownloader,
        urls: [URL]
    ) async -> [Result<Data, ImageLoadingError>] {
        var results: [Result<Data, ImageLoadingError>] = []
        for await result in downloader.stream(urls: urls) {
            results.append(result)
        }
        return results
    }

    // MARK: - 테스트

    @Test("뒤 장이 먼저 끝나도 넘긴 순서대로 나온다")
    func keepsInputOrder() async {
        let fetcher = MockImageDataFetcher { url in
            let index = Self.index(of: url)
            // 앞 장일수록 느리게 응답해 완료 순서를 뒤집는다.
            try? await Task.sleep(for: .milliseconds(40 - index * 10))
            return (Data("\(index)".utf8), Self.response(url))
        }
        let downloader = ImageDataBatchDownloader(
            fetcher: fetcher,
            condition: StubNetworkCondition(isConstrained: false),
            retryDelays: []
        )

        let results = await Self.collect(downloader, urls: Self.urls(4))

        let bodies = results.compactMap { try? $0.get() }.compactMap { String(bytes: $0, encoding: .utf8) }
        #expect(bodies == ["0", "1", "2", "3"])
    }

    @Test("동시에 받는 장수가 상한을 넘지 않는다")
    func limitsConcurrency() async {
        let recorder = ConcurrencyRecorder()
        let fetcher = MockImageDataFetcher { url in
            await recorder.begin()
            try? await Task.sleep(for: .milliseconds(20))
            await recorder.end()
            return (Data("x".utf8), Self.response(url))
        }
        let downloader = ImageDataBatchDownloader(
            fetcher: fetcher,
            condition: StubNetworkCondition(isConstrained: false),
            retryDelays: []
        )

        _ = await Self.collect(downloader, urls: Self.urls(12))

        #expect(await recorder.peak <= ImageDataBatchDownloader.defaultConcurrency)
    }

    @Test("셀룰러·저전력이면 동시 개수를 줄인다")
    func limitsConcurrencyOnConstrainedNetwork() async {
        let recorder = ConcurrencyRecorder()
        let fetcher = MockImageDataFetcher { url in
            await recorder.begin()
            try? await Task.sleep(for: .milliseconds(20))
            await recorder.end()
            return (Data("x".utf8), Self.response(url))
        }
        let downloader = ImageDataBatchDownloader(
            fetcher: fetcher,
            condition: StubNetworkCondition(isConstrained: true),
            retryDelays: []
        )

        _ = await Self.collect(downloader, urls: Self.urls(8))

        #expect(await recorder.peak <= ImageDataBatchDownloader.constrainedConcurrency)
    }

    @Test("한 장이 실패해도 나머지는 계속 받는다")
    func keepsGoingAfterFailure() async {
        let fetcher = MockImageDataFetcher { url in
            let index = Self.index(of: url)
            if index == 1 {
                return (Data("error".utf8), Self.response(url, status: 500))
            }
            return (Data("ok".utf8), Self.response(url))
        }
        let downloader = ImageDataBatchDownloader(
            fetcher: fetcher,
            condition: StubNetworkCondition(isConstrained: false),
            retryDelays: []
        )

        let results = await Self.collect(downloader, urls: Self.urls(3))

        #expect(results.count == 3)
        #expect((try? results[0].get()) != nil)
        #expect((try? results[2].get()) != nil)
        if case let .failure(error) = results[1] {
            #expect(error == .httpStatus(500))
        } else {
            Issue.record("두 번째 장은 실패여야 한다")
        }
    }

    @Test("본문이 비어 있으면 실패로 거른다")
    func rejectsEmptyBody() async {
        let fetcher = MockImageDataFetcher { url in
            (Data(), Self.response(url))
        }
        let downloader = ImageDataBatchDownloader(
            fetcher: fetcher,
            condition: StubNetworkCondition(isConstrained: false),
            retryDelays: []
        )

        let results = await Self.collect(downloader, urls: Self.urls(1))

        if case let .failure(error) = results[0] {
            #expect(error == .emptyData)
        } else {
            Issue.record("빈 본문은 실패여야 한다")
        }
    }

    @Test("소비를 멈추면 남은 장을 받지 않는다")
    func stopsFetchingWhenConsumerStops() async {
        let fetcher = MockImageDataFetcher { url in
            try? await Task.sleep(for: .milliseconds(10))
            return (Data("x".utf8), Self.response(url))
        }
        let downloader = ImageDataBatchDownloader(
            fetcher: fetcher,
            condition: StubNetworkCondition(isConstrained: false),
            retryDelays: []
        )

        for await _ in downloader.stream(urls: Self.urls(20)) {
            break // 한 장만 받고 그만둔다
        }
        // 취소가 전파될 틈을 준다.
        try? await Task.sleep(for: .milliseconds(100))

        // 창(4장)에 더해 한 장을 내보내며 채운 것까지가 상한이다. 20장을 다 받지 않는다.
        #expect(fetcher.callCount <= ImageDataBatchDownloader.defaultConcurrency + 1)
    }

    @Test("소비자를 취소하면 현재 결과를 기다리는 요청까지 모두 취소한다")
    func cancelsEveryInFlightRequest() async {
        let started = AsyncStream<Void>.makeStream()
        let finished = AsyncStream<Bool>.makeStream()
        let fetcher = MockImageDataFetcher { url in
            started.continuation.yield(())
            do {
                try await Task.sleep(for: .milliseconds(500))
                finished.continuation.yield(false)
                return (Data("x".utf8), Self.response(url))
            } catch {
                finished.continuation.yield(true)
                throw error
            }
        }
        let downloader = ImageDataBatchDownloader(
            fetcher: fetcher,
            condition: StubNetworkCondition(isConstrained: false),
            retryDelays: []
        )
        let consumer = Task {
            await Self.collect(downloader, urls: Self.urls(12))
        }
        var starts = started.stream.makeAsyncIterator()
        for _ in 0 ..< ImageDataBatchDownloader.defaultConcurrency {
            _ = await starts.next()
        }

        consumer.cancel()

        var completions = finished.stream.makeAsyncIterator()
        for _ in 0 ..< ImageDataBatchDownloader.defaultConcurrency {
            #expect(await completions.next() == true)
        }
        let results = await consumer.value
        #expect(results.isEmpty)
        #expect(fetcher.callCount == ImageDataBatchDownloader.defaultConcurrency)
    }

    @Test("받을 것이 없으면 아무 결과 없이 끝난다")
    func finishesOnEmptyInput() async {
        let fetcher = MockImageDataFetcher { url in (Data("x".utf8), Self.response(url)) }
        let downloader = ImageDataBatchDownloader(
            fetcher: fetcher,
            condition: StubNetworkCondition(isConstrained: false),
            retryDelays: []
        )

        let results = await Self.collect(downloader, urls: [])

        #expect(results.isEmpty)
        #expect(fetcher.callCount == 0)
    }
}
