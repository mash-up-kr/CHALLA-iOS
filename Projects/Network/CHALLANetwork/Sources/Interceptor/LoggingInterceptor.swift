import Foundation
import os

/// 요청/응답을 `os.Logger`로 남기는 인터셉터.
public struct LoggingInterceptor: Interceptor {

    public enum Level: Sendable {
        /// 로깅하지 않음.
        case none
        /// 메서드·URL·상태 코드만.
        case basic
        /// 헤더·본문까지 (`.private`로 마스킹되어 콘솔에서만 노출).
        case verbose
    }

    private let level: Level
    // TODO: Core/Logger 모듈이 생기면 os.Logger 직접 사용 대신 그쪽 로거에 위임한다.
    private let logger: Logger

    public init(
        level: Level = .basic,
        subsystem: String = "com.challa.network",
        category: String = "HTTP"
    ) {
        self.level = level
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func willSend(_ request: URLRequest, endpoint _: any Endpoint) {
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

    public func didReceive(_ result: Result<Response, NetworkError>, endpoint _: any Endpoint) {
        guard level != .none else { return }
        switch result {
        case let .success(response):
            let url = response.request?.url?.absoluteString ?? "?"
            logger.debug("← \(response.statusCode, privacy: .public) \(url, privacy: .private)")
            if level == .verbose, let string = String(data: response.data, encoding: .utf8) {
                logger.debug("  body: \(string, privacy: .private)")
            }
        case let .failure(error):
            // 오류 설명에 요청 URL이 포함될 수 있어 성공 경로와 동일하게 마스킹한다.
            logger.error("✕ \(String(describing: error), privacy: .private)")
        }
    }
}
