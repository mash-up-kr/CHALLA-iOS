import Foundation
import os

/// 주고받은 STOMP 프레임을 `os.Logger`로 남긴다.
///
/// 소켓은 HTTP와 달리 요청·응답 짝이 없어서, 무엇이 오갔는지 보려면 프레임 단위 기록이 필요하다.
/// 토큰이 로그에 남지 않도록 `Authorization` 헤더는 항상 가린다.
public struct STOMPLogger: Sendable {

    public enum Level: Sendable {
        case none
        /// 명령과 주요 헤더만.
        case basic
        /// 본문까지. 서버가 실제로 무엇을 보내는지 확인할 때 쓴다.
        case verbose
    }

    private let level: Level
    private let logger = Logger(subsystem: "com.challa.network", category: "STOMP")

    init(level: Level) {
        self.level = level
    }

    func sent(_ frame: STOMPFrame) {
        guard level != .none else { return }
        logger.debug("→ \(frame.command, privacy: .public) \(summary(frame), privacy: .public)")
    }

    func received(_ frame: STOMPFrame) {
        guard level != .none else { return }
        logger.debug("← \(frame.command, privacy: .public) \(summary(frame), privacy: .public)")
    }

    func note(_ message: String) {
        guard level != .none else { return }
        logger.debug("· \(message, privacy: .public)")
    }

    private func summary(_ frame: STOMPFrame) -> String {
        let headers = frame.headers
            .filter { $0.key != STOMPFrame.Header.authorization }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        guard level == .verbose, !frame.body.isEmpty else { return headers }
        let body = String(bytes: frame.body, encoding: .utf8) ?? "<binary \(frame.body.count)B>"
        return headers.isEmpty ? body : "\(headers) | \(body)"
    }
}
