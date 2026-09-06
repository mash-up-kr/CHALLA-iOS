import Foundation

/// 이미지 로더와 배치 다운로더가 공유하는 원본 다운로드·응답 검증.
struct RemoteImageData: Sendable {

    /// 오프라인 오류는 재시도하지 않는다.
    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotConnectToHost,
        .cannotFindHost,
        .networkConnectionLost,
        .dnsLookupFailed,
        .badServerResponse
    ]

    private let fetcher: any ImageDataFetching
    private let retryDelays: [Duration]

    init(fetcher: any ImageDataFetching, retryDelays: [Duration]) {
        self.fetcher = fetcher
        self.retryDelays = retryDelays
    }

    /// HTTP 성공 상태와 비어 있지 않은 응답 본문을 확인한다.
    func data(from url: URL) async throws -> Data {
        let (data, response) = try await fetchWithRetry(url)

        guard let http = response as? HTTPURLResponse else {
            throw ImageLoadingError.invalidResponse
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            throw ImageLoadingError.httpStatus(http.statusCode)
        }

        guard !data.isEmpty else {
            throw ImageLoadingError.emptyData
        }

        return data
    }

    private func fetchWithRetry(_ url: URL) async throws -> (Data, URLResponse) {
        var attempt = 0

        while true {
            do {
                return try await fetcher.fetch(url)
            } catch let error as URLError {
                if error.code == .cancelled {
                    throw ImageLoadingError.cancelled
                }

                guard
                    Self.retryableURLErrorCodes.contains(error.code),
                    attempt < retryDelays.count
                else {
                    throw ImageLoadingError.networkFailed(error.code)
                }

                do {
                    try await Task.sleep(for: retryDelays[attempt])
                } catch {
                    throw ImageLoadingError.cancelled
                }

                attempt += 1
            }
        }
    }
}
