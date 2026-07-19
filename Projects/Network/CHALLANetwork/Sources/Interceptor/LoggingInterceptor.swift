import Foundation
import os

/// 요청/응답을 `os.Logger`로 남기는 인터셉터. Moya의 `NetworkLoggerPlugin`에 대응한다.
///
/// > Core/Logger 모듈이 생기면 그쪽에 위임하도록 바꾼다 (그전까지는 `os.Logger` 직접 사용).
public struct LoggingInterceptor: Interceptor {

    /// 로깅 상세 수준.
    public enum Level: Sendable {
        /// 로깅하지 않음.
        case none
        /// 메서드·URL·상태 코드만.
        case basic
        /// 헤더·본문까지 (`.private`로 마스킹되어 콘솔에서만 노출).
        case verbose
    }

    private let level: Level
    private let logger: Logger

    public init(
        level: Level = .basic,
        subsystem: String = "com.challa.network",
        category: String = "HTTP"
    ) {
        self.level = level
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func willSend(_ request: URLRequest, endpoint: any Endpoint) {
        guard level != .none else { return }
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        // URL은 쿼리스트링에 토큰/PII가 실릴 수 있어 .private로 마스킹한다 (디버깅 시엔 콘솔에 노출).
        logger.debug("→ \(method, privacy: .public) \(url, privacy: .private)")

        guard level == .verbose else { return }
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logger.debug("  headers: \(String(describing: headers), privacy: .private)")
        }
        if let body = request.httpBody, let string = String(data: body, encoding: .utf8) {
            logger.debug("  body: \(string, privacy: .private)")
        }
    }

    public func didReceive(_ result: Result<Response, NetworkError>, endpoint: any Endpoint) {
        guard level != .none else { return }
        switch result {
        case .success(let response):
            let url = response.request?.url?.absoluteString ?? "?"
            logger.debug("← \(response.statusCode, privacy: .public) \(url, privacy: .private)")
            if level == .verbose, let string = String(data: response.data, encoding: .utf8) {
                logger.debug("  body: \(string, privacy: .private)")
            }
        case .failure(let error):
            logger.error("✕ \(String(describing: error), privacy: .public)")
        }
    }
}
