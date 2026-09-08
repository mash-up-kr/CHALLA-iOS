import Foundation

/// STOMP 프레임 한 개. `명령\n헤더:값\n\n본문\0` 구조를 그대로 담는다.
///
/// 명령을 enum이 아니라 String으로 두는 이유: 서버가 새 명령을 추가해도 디코딩이 깨지지 않는다.
/// 알려진 명령 판별은 `knownCommand`가 맡는다.
struct STOMPFrame: Equatable, Sendable {

    let command: String
    let headers: [String: String]
    let body: Data

    init(command: String, headers: [String: String] = [:], body: Data = Data()) {
        self.command = command
        self.headers = headers
        self.body = body
    }

    init(command: STOMPCommand, headers: [String: String] = [:], body: Data = Data()) {
        self.init(command: command.rawValue, headers: headers, body: body)
    }

    var knownCommand: STOMPCommand? {
        STOMPCommand(rawValue: command)
    }

    /// 프레임을 WebSocket 텍스트 메시지로 직렬화한다.
    ///
    /// 본문은 UTF-8 텍스트(JSON)만 보낸다고 가정한다 — 이 클라이언트는 바이너리 본문을 전송하지 않는다.
    func encoded() -> String {
        var text = command + "\n"

        var headers = headers
        // 본문이 있으면 길이를 명시한다. 서버가 본문 안의 NULL에서 잘못 끊지 않는다.
        if !body.isEmpty, headers[Header.contentLength] == nil {
            headers[Header.contentLength] = String(body.count)
        }

        // 정렬은 STOMP 요구사항이 아니라 테스트가 출력을 비교할 수 있게 하려는 것이다.
        for (name, value) in headers.sorted(by: { $0.key < $1.key }) {
            text += Self.escapeIfNeeded(name, command: command)
            text += ":"
            text += Self.escapeIfNeeded(value, command: command)
            text += "\n"
        }

        text += "\n"
        // 이 클라이언트는 UTF-8 텍스트 본문만 보낸다. 아니면 본문 없이 보내 프레임이 깨지지 않게 한다.
        text += String(bytes: body, encoding: .utf8) ?? ""
        text += "\0"
        return text
    }

    /// CONNECT·CONNECTED는 이스케이프하지 않는다 (STOMP 1.2 명세).
    /// STOMP 1.0 서버와의 호환을 위해 명세가 둔 예외다.
    static func escapesHeaders(command: String) -> Bool {
        command != STOMPCommand.connect.rawValue && command != STOMPCommand.connected.rawValue
    }

    private static func escapeIfNeeded(_ value: String, command: String) -> String {
        guard escapesHeaders(command: command) else { return value }
        var escaped = ""
        for character in value {
            switch character {
            case "\\": escaped += "\\\\"
            case "\r": escaped += "\\r"
            case "\n": escaped += "\\n"
            case ":": escaped += "\\c"
            default: escaped.append(character)
            }
        }
        return escaped
    }

    enum Header {
        static let contentLength = "content-length"
        static let destination = "destination"
        static let id = "id"
        static let receipt = "receipt"
        static let receiptID = "receipt-id"
        static let subscription = "subscription"
        static let message = "message"
        static let heartBeat = "heart-beat"
        static let acceptVersion = "accept-version"
        static let host = "host"
        static let authorization = "Authorization"
        static let ack = "ack"
    }
}

/// 이 클라이언트가 다루는 STOMP 명령.
enum STOMPCommand: String, Sendable {
    case connect = "CONNECT"
    case connected = "CONNECTED"
    case subscribe = "SUBSCRIBE"
    case unsubscribe = "UNSUBSCRIBE"
    case send = "SEND"
    case message = "MESSAGE"
    case receipt = "RECEIPT"
    case error = "ERROR"
    case disconnect = "DISCONNECT"
}

// MARK: - 이 클라이언트가 보내는 프레임

extension STOMPFrame {

    static func connect(host: String, token: String?, heartbeatMilliseconds: Int) -> STOMPFrame {
        var headers = [
            Header.acceptVersion: "1.2",
            Header.host: host,
            // 보내는 쪽만 켠다. 받는 쪽 워치독은 두지 않는다 — URLSession이 끊긴 소켓을 오류로 알려준다.
            Header.heartBeat: "\(heartbeatMilliseconds),0"
        ]
        if let token {
            // 서버가 CONNECT 프레임에서 토큰을 읽는 구현일 수도 있어 핸드셰이크 헤더와 양쪽에 넣는다.
            headers[Header.authorization] = "Bearer \(token)"
        }
        return STOMPFrame(command: .connect, headers: headers)
    }

    static func subscribe(id: String, destination: String, receipt: String) -> STOMPFrame {
        STOMPFrame(command: .subscribe, headers: [
            Header.id: id,
            Header.destination: destination,
            Header.ack: "auto",
            Header.receipt: receipt
        ])
    }

    static func unsubscribe(id: String) -> STOMPFrame {
        STOMPFrame(command: .unsubscribe, headers: [Header.id: id])
    }

    static func disconnect() -> STOMPFrame {
        STOMPFrame(command: .disconnect)
    }
}
