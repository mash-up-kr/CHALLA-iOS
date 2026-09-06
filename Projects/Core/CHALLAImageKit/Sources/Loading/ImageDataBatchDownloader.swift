import Foundation

/// 원본 이미지를 병렬로 다운로드한다. 다운샘플링과 캐시는 사용하지 않는다.
/// 결과는 입력 순서대로 반환한다.
public struct ImageDataBatchDownloader: Sendable {

    /// 기본 동시 다운로드 수.
    public static let defaultConcurrency = 4
    /// 셀룰러·저데이터·저전력 모드의 동시 다운로드 수.
    public static let constrainedConcurrency = 2

    private let transfer: RemoteImageData
    private let condition: any NetworkCondition

    /// - Parameter retryDelays: 재시도 간격. 기본값은 1초 후 한 번 재시도한다.
    public init(
        fetcher: any ImageDataFetching = URLSessionImageDataFetcher(),
        condition: any NetworkCondition = SystemNetworkCondition.shared,
        retryDelays: [Duration] = [.seconds(1)]
    ) {
        self.transfer = RemoteImageData(fetcher: fetcher, retryDelays: retryDelays)
        self.condition = condition
    }

    /// 개별 다운로드 실패 후에도 나머지 결과를 반환한다.
    /// 동시 다운로드 수는 시작 시점의 네트워크·전력 상태로 결정한다.
    public func stream(urls: [URL]) -> AsyncStream<Result<Data, ImageLoadingError>> {
        stream(urls: urls, mapError: { $0 })
    }

    /// 실패를 호출부의 오류 타입으로 바꿔 흘려 준다.
    ///
    /// 결과를 받아 다른 `AsyncStream`에 다시 담으면 안 된다 — 기본 버퍼가 무제한이라
    /// 전달 쪽이 소비 속도와 무관하게 앞서 나가고, 이 스트림의 메모리 상한이 무너진다.
    /// 변환이 필요하면 여기서 함께 처리한다.
    public func stream<Failure: Error>(
        urls: [URL],
        mapError: @escaping @Sendable (ImageLoadingError) -> Failure
    ) -> AsyncStream<Result<Data, Failure>> {
        let session = BatchSession(
            urls: urls,
            transfer: transfer,
            maxConcurrent: condition.isConstrained ? Self.constrainedConcurrency : Self.defaultConcurrency
        )

        return AsyncStream(
            unfolding: { await session.next()?.mapError(mapError) },
            onCancel: { Task { await session.cancelAll() } }
        )
    }
}

// MARK: - 진행 상태

/// 진행 중인 다운로드를 관리하고 입력 순서대로 결과를 반환한다.
private actor BatchSession {

    private let urls: [URL]
    private let transfer: RemoteImageData
    private let maxConcurrent: Int

    /// 진행 중이거나 반환 대기 중인 작업.
    private var window: [Int: Task<Data, any Error>] = [:]
    private var nextToStart = 0
    private var nextToEmit = 0
    private var isCancelled = false

    init(urls: [URL], transfer: RemoteImageData, maxConcurrent: Int) {
        self.urls = urls
        self.transfer = transfer
        self.maxConcurrent = max(1, maxConcurrent)
    }

    deinit {
        for task in window.values {
            task.cancel()
        }
    }

    /// 완료 또는 취소 시 nil을 반환한다.
    func next() async -> Result<Data, ImageLoadingError>? {
        guard !isCancelled, !Task.isCancelled else { return nil }
        fill()

        guard nextToEmit < urls.count, let task = window[nextToEmit] else {
            return nil
        }
        let index = nextToEmit
        nextToEmit += 1

        let result = await task.result
        guard !isCancelled, !Task.isCancelled else {
            cancelAll()
            return nil
        }
        window.removeValue(forKey: index)
        fill()

        switch result {
        case let .success(data):
            return .success(data)
        case let .failure(error):
            return .failure(Self.loadingError(from: error))
        }
    }

    /// 일반 오류가 취소로 처리되지 않도록 구분한다.
    private static func loadingError(from error: any Error) -> ImageLoadingError {
        if let loading = error as? ImageLoadingError {
            return loading
        }
        return error is CancellationError ? .cancelled : .networkFailed(.unknown)
    }

    private func fill() {
        while !isCancelled, window.count < maxConcurrent, nextToStart < urls.count {
            let url = urls[nextToStart]
            window[nextToStart] = Task { [transfer] in
                try await transfer.data(from: url)
            }
            nextToStart += 1
        }
    }

    func cancelAll() {
        isCancelled = true
        for task in window.values {
            task.cancel()
        }
        window.removeAll()
    }
}
