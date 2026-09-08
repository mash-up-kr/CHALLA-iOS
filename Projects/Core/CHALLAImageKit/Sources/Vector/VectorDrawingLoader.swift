import Foundation

/// 원격 SVG를 ``VectorDrawing``으로 받아 메모리에 캐시한다.
///
/// 디스크 캐시는 두지 않는다 — 스티커는 7개·수 KB라 메모리로 충분하고,
/// ``ImageLoader``의 디스크 캐시는 JPEG 비트맵이라 형식이 달라 섞을 수 없다.
public actor VectorDrawingLoader {

    // MARK: - Properties

    private let fetcher: any ImageDataFetching
    private let parser = SVGShapeParser()

    private let maxCount: Int

    private var cache: [URL: VectorDrawing] = [:]

    /// 오래 안 쓰인 순서. 항목이 수십 개 규모라 배열 LRU로 충분하다.
    private var recentlyUsed: [URL] = []

    /// 같은 URL 요청이 겹치면 새로 받지 않고 이 작업의 결과를 공유한다.
    private var inFlight: [URL: Task<VectorDrawing, Error>] = [:]

    // MARK: - Initialization

    public init(
        fetcher: any ImageDataFetching = URLSessionImageDataFetcher(),
        maxCount: Int = 32
    ) {
        self.fetcher = fetcher
        self.maxCount = max(1, maxCount)
    }

    // MARK: - Public Methods

    public func drawing(from url: URL) async throws -> VectorDrawing {
        if let cached = cache[url] {
            touch(url)
            return cached
        }

        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<VectorDrawing, Error> { [self] in
            try await load(url)
        }

        inFlight[url] = task
        defer { inFlight[url] = nil }

        return try await task.value
    }

    // MARK: - Private Methods

    private func load(_ url: URL) async throws -> VectorDrawing {
        let (data, response) = try await fetch(url)

        guard let http = response as? HTTPURLResponse else {
            throw ImageLoadingError.invalidResponse
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            throw ImageLoadingError.httpStatus(http.statusCode)
        }

        guard !data.isEmpty else {
            throw ImageLoadingError.emptyData
        }

        let drawing = try parser.parse(data)
        insert(drawing, for: url)

        return drawing
    }

    private func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await fetcher.fetch(url)
        } catch let error as URLError {
            throw error.code == .cancelled
                ? ImageLoadingError.cancelled
                : ImageLoadingError.networkFailed(error.code)
        }
    }

    private func insert(_ drawing: VectorDrawing, for url: URL) {
        cache[url] = drawing
        touch(url)

        while recentlyUsed.count > maxCount, let oldest = recentlyUsed.first {
            recentlyUsed.removeFirst()
            cache[oldest] = nil
        }
    }

    private func touch(_ url: URL) {
        recentlyUsed.removeAll { $0 == url }
        recentlyUsed.append(url)
    }
}
