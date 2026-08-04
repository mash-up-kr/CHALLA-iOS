import Foundation

/// 원본 이미지 바이트를 원격에서 가져오는 추상화.
///
/// `ImageLoader`가 네트워크 계층을 직접 붙들지 않도록 프로토콜로 분리한다.
/// 덕분에 테스트에서는 `URLProtocol` 목이나 고정 바이트를 반환하는 스텁으로 대체할 수 있다.
public protocol ImageDataFetching: Sendable {

    /// 주어진 URL에서 바이트와 응답을 가져온다.
    /// - Throws: 전송 실패 시 `URLError` (호출부 `ImageLoader`가 `ImageLoadingError.networkFailed`로 매핑)
    func fetch(_ url: URL) async throws -> (Data, URLResponse)
}

/// `URLSession` 기반 기본 구현.
public struct URLSessionImageDataFetcher: ImageDataFetching {

    // MARK: - Properties

    private let session: URLSession

    // MARK: - Initialization

    /// - Parameter session: 사용할 세션. 기본값은 URLCache를 끈 전용 세션이다(아래 참고).
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
    /// 결정(이슈 #25): 이 모듈은 URLCache를 사용하지 않는다.
    /// `URLSession.shared`(또는 URLCache가 켜진 세션)를 쓰면 URLSession이 원본(고해상도) 바이트를
    /// 자체 캐시에 저장하고, 우리는 그것을 다시 다운샘플·재인코딩해 `DiskImageCache`에 또 저장한다.
    /// 즉 같은 이미지가 원본·가공본으로 이중 저장되어 디스크를 낭비한다.
    /// 그래서 세션 캐시를 끄고(`urlCache = nil`, `.reloadIgnoringLocalCacheData`),
    /// 캐싱 책임은 전적으로 우리 `MemoryImageCache`/`DiskImageCache`가 진다.
    public static func makeCacheDisabledSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
}
