@testable import CHALLANetwork
import Foundation
import Testing

@Suite("STOMPCodec")
struct STOMPCodecTests {

    private func decode(_ text: String) throws -> STOMPCodec.Decoded {
        let result = STOMPCodec.decode(Data(text.utf8))
        if let error = result.error {
            throw error
        }
        return result
    }

    private func text(_ body: Data) -> String? {
        String(bytes: body, encoding: .utf8)
    }

    // MARK: - 프레임 경계

    @Test("NULL로 끝나지 않은 프레임은 remainder로 남고, 다음 청크와 이어 붙이면 완성된다")
    func incompleteFrameIsBuffered() throws {
        let first = try decode("MESSAGE\ndestination:/topic/a\n\n부분")
        #expect(first.frames.isEmpty)
        #expect(!first.remainder.isEmpty)

        let completed = try STOMPCodec.decode(first.remainder + Data("본문\0".utf8))
        #expect(completed.frames.count == 1)
        #expect(text(completed.frames[0].body) == "부분본문")
        #expect(completed.remainder.isEmpty)
    }

    @Test("WebSocket 메시지 하나에 실린 프레임 여러 개를 모두 잘라낸다")
    func multipleFramesInOneMessage() throws {
        let result = try decode("CONNECTED\nversion:1.2\n\n\0MESSAGE\nsubscription:sub-0\n\nhi\0")
        #expect(result.frames.count == 2)
        #expect(result.frames[0].knownCommand == .connected)
        #expect(result.frames[1].headers["subscription"] == "sub-0")
        #expect(result.remainder.isEmpty)
    }

    @Test("프레임 사이의 하트비트 개행은 건너뛴다")
    func heartbeatEndOfLinesAreSkipped() throws {
        #expect(try decode("\n").frames.isEmpty)
        #expect(try decode("\r\n").frames.isEmpty)

        let result = try decode("\n\r\nRECEIPT\nreceipt-id:sub-0\n\n\0\n")
        #expect(result.frames.count == 1)
        #expect(result.frames[0].headers["receipt-id"] == "sub-0")
        #expect(result.remainder.isEmpty)
    }

    // MARK: - 본문

    @Test("content-length가 있으면 본문 안의 NULL에서 끊지 않는다")
    func contentLengthKeepsInteriorNull() throws {
        var data = Data("MESSAGE\ncontent-length:3\n\n".utf8)
        data.append(contentsOf: [0x61, 0x00, 0x62, 0x00]) // 본문 "a\0b" + 종단 NULL

        let result = try STOMPCodec.decode(data)
        #expect(result.frames.count == 1)
        #expect(Array(result.frames[0].body) == [0x61, 0x00, 0x62])
        #expect(result.remainder.isEmpty)
    }

    @Test("content-length가 없으면 첫 NULL까지가 본문이다")
    func bodyRunsToFirstNull() throws {
        let result = try decode("MESSAGE\n\n{\"a\":1}\0")
        #expect(text(result.frames[0].body) == "{\"a\":1}")
    }

    @Test("본문 안의 빈 줄에서 헤더가 다시 끊기지 않는다")
    func blankLineInsideBody() throws {
        let result = try decode("MESSAGE\nx:1\n\n첫 줄\n\n셋째 줄\0")
        #expect(result.frames[0].headers["x"] == "1")
        #expect(text(result.frames[0].body) == "첫 줄\n\n셋째 줄")
    }

    // MARK: - 헤더

    @Test("헤더 이스케이프를 왕복 처리한다")
    func headerEscapingRoundTrip() throws {
        let original = STOMPFrame(command: .send, headers: ["k:1": "a\nb\\c:d"])
        let decoded = try decode(original.encoded())
        #expect(decoded.frames[0].headers["k:1"] == "a\nb\\c:d")
    }

    @Test("CONNECT·CONNECTED 헤더는 이스케이프하지 않는다")
    func connectFramesSkipEscaping() throws {
        #expect(STOMPFrame(command: .connect, headers: ["host": "a.com"]).encoded().contains("host:a.com"))

        // 이스케이프를 풀지 않으므로 백슬래시가 그대로 남는다.
        let decoded = try decode("CONNECTED\nserver:x\\ny\n\n\0")
        #expect(decoded.frames[0].headers["server"] == "x\\ny")
    }

    @Test("같은 헤더가 반복되면 첫 값이 이긴다")
    func repeatedHeaderKeepsFirst() throws {
        let result = try decode("MESSAGE\nx:1\nx:2\n\n\0")
        #expect(result.frames[0].headers["x"] == "1")
    }

    @Test("CRLF 줄바꿈을 LF와 동일하게 해석한다")
    func carriageReturnLineFeed() throws {
        let lineFeed = try decode("MESSAGE\ndestination:/topic/a\n\nhi\0")
        let carriageReturn = try decode("MESSAGE\r\ndestination:/topic/a\r\n\r\nhi\0")
        #expect(lineFeed.frames == carriageReturn.frames)
    }

    // MARK: - 오류와 전방 호환

    @Test("UTF-8이 아닌 바이트는 malformedFrame으로 알린다")
    func invalidUTF8() {
        var data = Data([0xFF, 0xFE])
        data.append(Data("\n\n\0".utf8))
        #expect(STOMPCodec.decode(data).error != nil)
    }

    @Test("':'가 없는 헤더 줄은 malformedFrame으로 알린다")
    func headerWithoutSeparator() {
        #expect(STOMPCodec.decode(Data("MESSAGE\nbroken\n\n\0".utf8)).error != nil)
    }

    @Test("content-length가 숫자가 아니면 malformedFrame으로 알린다")
    func invalidContentLength() {
        #expect(STOMPCodec.decode(Data("MESSAGE\ncontent-length:x\n\n\0".utf8)).error != nil)
    }

    @Test("명세에 없는 이스케이프는 malformedFrame으로 알린다")
    func undefinedEscape() {
        #expect(STOMPCodec.decode(Data("MESSAGE\nx:a\\tb\n\n\0".utf8)).error != nil)
    }

    @Test("ERROR 프레임을 명령과 message 헤더로 노출한다")
    func errorFrame() throws {
        let result = try decode("ERROR\nmessage:bad token\n\n\0")
        #expect(result.frames[0].knownCommand == .error)
        #expect(result.frames[0].headers["message"] == "bad token")
    }

    @Test("모르는 명령도 버리지 않고 담는다")
    func unknownCommandIsKept() throws {
        let result = try decode("FUTURE\nx:1\n\n\0")
        #expect(result.frames[0].command == "FUTURE")
        #expect(result.frames[0].knownCommand == nil)
    }

    // MARK: - 인코딩

    @Test("본문이 있으면 content-length를 바이트 수로 붙인다")
    func encodesContentLength() {
        let encoded = STOMPFrame(
            command: .send,
            headers: ["destination": "/app/x"],
            body: Data("한글".utf8)
        ).encoded()

        #expect(encoded.contains("content-length:6")) // "한글"은 UTF-8로 6바이트
        #expect(encoded.hasSuffix("한글\0"))
    }

    @Test("본문이 없으면 content-length를 붙이지 않는다")
    func emptyBodyHasNoContentLength() {
        let encoded = STOMPFrame(command: .unsubscribe, headers: ["id": "sub-0"]).encoded()
        #expect(encoded == "UNSUBSCRIBE\nid:sub-0\n\n\0")
    }
}

@Suite("STOMPCodec — 깨진 프레임 처리")
struct STOMPCodecPartialTests {

    @Test("앞의 정상 프레임은 살리고 깨진 것만 버린다")
    func keepsGoodFramesBeforeMalformed() {
        // 정상 2건 뒤에 ':' 없는 헤더가 붙어 온 경우.
        let text = "CONNECTED\nversion:1.2\n\n\u{0}MESSAGE\nsubscription:sub-1\n\nhi\u{0}MESSAGE\nbroken\n\n\u{0}"
        let result = STOMPCodec.decode(Data(text.utf8))

        #expect(result.frames.count == 2)
        #expect(result.frames[1].headers["subscription"] == "sub-1")
        #expect(result.error != nil)
    }

    @Test("정상만 있으면 오류가 없다")
    func noErrorWhenAllValid() {
        let result = STOMPCodec.decode(Data("MESSAGE\nx:1\n\nhi\u{0}".utf8))
        #expect(result.frames.count == 1)
        #expect(result.error == nil)
    }
}

@Suite("STOMPCodec — 악의적·비정상 content-length")
struct STOMPCodecContentLengthTests {

    @Test("Int 범위를 넘는 content-length에 죽지 않는다")
    func hugeContentLengthDoesNotTrap() {
        let result = STOMPCodec.decode(Data("MESSAGE\ncontent-length:9223372036854775807\n\n\u{0}".utf8))
        #expect(result.error != nil)
    }

    @Test("상한을 넘는 content-length는 거절한다 (버퍼 무한 축적 방지)")
    func oversizedContentLengthRejected() {
        let result = STOMPCodec.decode(Data("MESSAGE\ncontent-length:10000000000\n\n\u{0}".utf8))
        #expect(result.error != nil)
    }

    @Test("음수 content-length는 거절한다")
    func negativeContentLengthRejected() {
        let result = STOMPCodec.decode(Data("MESSAGE\ncontent-length:-1\n\n\u{0}".utf8))
        #expect(result.error != nil)
    }
}
