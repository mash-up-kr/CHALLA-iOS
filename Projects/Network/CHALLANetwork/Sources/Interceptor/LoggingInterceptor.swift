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
            if level == .verbose {
                logResponseBody(response.data)
            }
        case let .failure(error):
            // 오류 설명에 요청 URL이 포함될 수 있어 성공 경로와 동일하게 마스킹한다.
            logger.error("✕ \(String(describing: error), privacy: .private)")
        }
    }

    /// 응답 본문을 잘리지 않게 남긴다.
    ///
    /// `os.Logger`는 한 줄에 담기는 동적 문자열을 1024바이트에서 끊어버리므로,
    /// 그보다 긴 본문은 순번을 붙여 여러 줄로 쪼갠다.
    private func logResponseBody(_ data: Data) {
        guard !data.isEmpty else { return }
        guard let string = String(data: data, encoding: .utf8) else {
            logger.debug("  body: <디코딩 불가, \(data.count, privacy: .public) bytes>")
            return
        }

        let chunks = Self.split(string, byteLimit: Self.chunkByteLimit)
        for (index, chunk) in chunks.enumerated() {
            let label = chunks.count == 1 ? "body" : "body[\(index + 1)/\(chunks.count)]"
            logger.debug("  \(label, privacy: .public): \(chunk, privacy: .private)")
        }
    }

    /// os_log 한 줄 상한(1024바이트)에서 접두어·순번 표기 몫을 빼고 남긴 여유값.
    private static let chunkByteLimit = 800

    /// 문자 경계를 지키면서 UTF-8 바이트 수 기준으로 자른다 — 문자 단위로 자르면 한글이 상한을 넘길 수 있다.
    private static func split(_ string: String, byteLimit: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        var currentBytes = 0

        for character in string {
            let size = character.utf8.count
            if currentBytes + size > byteLimit, !current.isEmpty {
                chunks.append(current)
                current = ""
                currentBytes = 0
            }
            current.append(character)
            currentBytes += size
        }
        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks
    }
}
