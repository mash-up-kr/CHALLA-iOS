import Foundation

/// 원본 이미지 바이트를 원격에서 가져오는 추상화 — `ImageLoader`의 네트워크 주입 지점.
/// 테스트는 고정 바이트를 반환하는 목 구현을 주입해 네트워크 없이 검증한다.
public protocol ImageDataFetching: Sendable {

    /// 주어진 URL에서 바이트와 응답을 가져온다.
    /// - Throws: 전송 실패 시 `URLError` (호출부 `ImageLoader`가 `ImageLoadingError.networkFailed`로 매핑)
    func fetch(_ url: URL) async throws -> (Data, URLResponse)
}

/// `ImageDataFetching`의 실제 네트워크 구현 — `ImageLoader` 생성 시 기본값으로 주입된다.
/// `URLSession.data(from:)` 호출이 전부이며, 세션은 기본적으로 URLCache를 끈 것을 쓴다.
public struct URLSessionImageDataFetcher: ImageDataFetching {

    // MARK: - Properties

    private let session: URLSession

    // MARK: - Initialization

    /// - Parameter session: 사용할 세션. 기본값은 `makeCacheDisabledSession()`이 만든 URLCache 없는 세션.
    public init(session: URLSession = URLSessionImageDataFetcher.makeCacheDisabledSession()) {
        self.session = session
    }

    // MARK: - Public Methods

    public func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        try await session.data(from: url)
    }

    // MARK: - Private Methods

    /// URLCache를 완전히 끈 세션을 만든다.
    ///
    /// 이 모듈은 URLCache를 쓰지 않는다. URLCache가 켜진 세션은 원본(고해상도)
    /// 바이트를 자체 캐시에 저장해, `DiskImageCache`의 다운샘플본과 같은 이미지가 이중 저장된다.
    /// 캐싱은 `MemoryImageCache`/`DiskImageCache`가 전담한다.
    public static func makeCacheDisabledSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
}
