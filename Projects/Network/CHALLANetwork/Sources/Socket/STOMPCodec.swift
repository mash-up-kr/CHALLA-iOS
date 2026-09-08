import Foundation

/// WebSocket으로 들어온 바이트를 STOMP 프레임으로 자른다.
///
/// 문자열이 아니라 바이트로 다루는 이유: `content-length`는 문자 수가 아니라 바이트 수이고,
/// 그 길이 안에는 NULL이 들어 있을 수 있다.
enum STOMPCodec {

    private static let lineFeed: UInt8 = 0x0A
    private static let carriageReturn: UInt8 = 0x0D
    private static let null: UInt8 = 0x00

    /// 한 프레임 본문의 상한. 채팅·참여 이벤트는 수 KB를 넘지 않는다.
    private static let maxBodyLength = 4 * 1024 * 1024

    /// - Returns: 완성된 프레임들, 아직 끝나지 않은 마지막 프레임의 바이트(`remainder`),
    ///   그리고 도중에 만난 오류(`error`).
    ///
    ///   한 프레임이 WebSocket 메시지 여러 개에 걸쳐 오므로, 호출부는 remainder를 다음 메시지 앞에 이어 붙인다.
    ///
    ///   오류를 던지지 않고 돌려주는 이유: 한 덩어리에 정상 프레임 여러 개와 깨진 것 하나가 섞여 올 수 있다.
    ///   던져 버리면 이미 읽어 둔 정상 프레임까지 함께 사라져 채팅이 조용히 유실된다.
    struct Decoded {
        let frames: [STOMPFrame]
        /// 아직 끝나지 않은 마지막 프레임의 바이트. 다음 메시지 앞에 이어 붙인다.
        let remainder: Data
        /// 도중에 만난 오류. 앞서 읽은 `frames`는 그대로 쓸 수 있다.
        let error: STOMPError?
    }

    static func decode(_ buffer: Data) -> Decoded {
        let bytes = [UInt8](buffer)
        var frames: [STOMPFrame] = []
        var index = 0

        while true {
            // 프레임 사이에 오는 개행은 하트비트다.
            index = skippingEndOfLines(bytes, from: index)
            guard index < bytes.count else { return Decoded(frames: frames, remainder: Data(), error: nil) }

            do {
                guard let parsed = try parseFrame(bytes, from: index) else {
                    return Decoded(frames: frames, remainder: Data(bytes[index...]), error: nil)
                }
                frames.append(parsed.frame)
                index = parsed.next
            } catch let error as STOMPError {
                // 깨진 지점부터는 어디가 프레임 경계인지 알 수 없어 남은 바이트를 버린다.
                // 이미 읽어 둔 정상 프레임은 그대로 돌려준다.
                return Decoded(frames: frames, remainder: Data(), error: error)
            } catch {
                return Decoded(frames: frames, remainder: Data(), error: .malformedFrame(reason: error.localizedDescription))
            }
        }
    }

    /// 프레임 하나를 읽는다. 바이트가 모자라면 nil (오류가 아니라 "더 기다려라").
    private static func parseFrame(
        _ bytes: [UInt8],
        from start: Int
    ) throws -> (frame: STOMPFrame, next: Int)? {
        guard let commandLineEnd = firstIndex(of: lineFeed, in: bytes, from: start) else { return nil }
        let command = try string(bytes, start ..< withoutCarriageReturn(bytes, upTo: commandLineEnd))
        guard !command.isEmpty else {
            throw STOMPError.malformedFrame(reason: "명령이 비어 있습니다.")
        }

        var index = commandLineEnd + 1
        var headers: [String: String] = [:]
        let escapes = STOMPFrame.escapesHeaders(command: command)

        while true {
            guard let lineEnd = firstIndex(of: lineFeed, in: bytes, from: index) else { return nil }
            let contentEnd = withoutCarriageReturn(bytes, upTo: lineEnd)
            // 빈 줄이 헤더의 끝이다. 본문에 빈 줄이 있어도 여기서 한 번만 끊긴다.
            if contentEnd == index {
                index = lineEnd + 1
                break
            }
            let line = try string(bytes, index ..< contentEnd)
            guard let separator = line.firstIndex(of: ":") else {
                throw STOMPError.malformedFrame(reason: "헤더에 ':'가 없습니다: \(line)")
            }
            let name = try unescape(String(line[line.startIndex ..< separator]), escapes: escapes)
            let value = try unescape(String(line[line.index(after: separator)...]), escapes: escapes)
            // 같은 헤더가 반복되면 첫 값이 이긴다 (STOMP 1.2).
            if headers[name] == nil {
                headers[name] = value
            }
            index = lineEnd + 1
        }

        return try parseBody(bytes, from: index, command: command, headers: headers)
    }

    /// `content-length`가 있으면 그 길이를 신뢰하고, 없으면 첫 NULL까지가 본문이다.
    private static func parseBody(
        _ bytes: [UInt8],
        from index: Int,
        command: String,
        headers: [String: String]
    ) throws -> (frame: STOMPFrame, next: Int)? {
        if let raw = headers[STOMPFrame.Header.contentLength] {
            guard let length = Int(raw), length >= 0, length <= maxBodyLength else {
                // 상한을 두는 이유: 네트워크가 준 값을 그대로 더하면 Int가 넘쳐 프로세스가 죽고,
                // 넘치지 않을 만큼 큰 값이면 영원히 "덜 왔다"로 판정돼 버퍼가 무한히 쌓인다.
                throw STOMPError.malformedFrame(reason: "content-length가 올바르지 않습니다: \(raw)")
            }
            let (bodyEnd, overflowed) = index.addingReportingOverflow(length)
            guard !overflowed else {
                throw STOMPError.malformedFrame(reason: "content-length가 범위를 넘습니다: \(raw)")
            }
            guard bytes.count > bodyEnd else { return nil } // 본문과 NULL이 아직 다 오지 않았다
            guard bytes[bodyEnd] == null else {
                throw STOMPError.malformedFrame(reason: "content-length 뒤에 NULL이 없습니다.")
            }
            let frame = STOMPFrame(command: command, headers: headers, body: Data(bytes[index ..< bodyEnd]))
            return (frame, bodyEnd + 1)
        }

        guard let nullIndex = firstIndex(of: null, in: bytes, from: index) else { return nil }
        let frame = STOMPFrame(command: command, headers: headers, body: Data(bytes[index ..< nullIndex]))
        return (frame, nullIndex + 1)
    }

    // MARK: - 바이트 도우미

    private static func skippingEndOfLines(_ bytes: [UInt8], from start: Int) -> Int {
        var index = start
        while index < bytes.count, bytes[index] == lineFeed || bytes[index] == carriageReturn {
            index += 1
        }
        return index
    }

    private static func firstIndex(of byte: UInt8, in bytes: [UInt8], from start: Int) -> Int? {
        var index = start
        while index < bytes.count {
            if bytes[index] == byte {
                return index
            }
            index += 1
        }
        return nil
    }

    /// CRLF로 끝나는 줄에서 CR를 잘라낸다. LF만 쓰는 줄은 그대로 둔다.
    private static func withoutCarriageReturn(_ bytes: [UInt8], upTo lineEnd: Int) -> Int {
        lineEnd > 0 && bytes[lineEnd - 1] == carriageReturn ? lineEnd - 1 : lineEnd
    }

    private static func string(_ bytes: [UInt8], _ range: Range<Int>) throws -> String {
        guard let text = String(bytes: bytes[range], encoding: .utf8) else {
            throw STOMPError.malformedFrame(reason: "UTF-8이 아닌 바이트가 있습니다.")
        }
        return text
    }

    private static func unescape(_ value: String, escapes: Bool) throws -> String {
        guard escapes, value.contains("\\") else { return value }

        var result = ""
        var iterator = value.makeIterator()
        while let character = iterator.next() {
            guard character == "\\" else {
                result.append(character)
                continue
            }
            guard let escaped = iterator.next() else {
                throw STOMPError.malformedFrame(reason: "헤더가 백슬래시로 끝납니다.")
            }
            switch escaped {
            case "r": result.append("\r")
            case "n": result.append("\n")
            case "c": result.append(":")
            case "\\": result.append("\\")
            default:
                // 명세가 정의하지 않은 이스케이프는 치명적 오류로 규정돼 있다.
                throw STOMPError.malformedFrame(reason: "알 수 없는 이스케이프입니다: \\\(escaped)")
            }
        }
        return result
    }
}
