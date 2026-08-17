@testable import CHALLANetwork
import Foundation
import Testing

@Suite("LoggingInterceptor 본문 분할")
struct LoggingInterceptorTests {

    @Test("상한보다 짧은 본문은 한 조각으로 남는다")
    func shortBodyStaysWhole() {
        let chunks = LoggingInterceptor.split(#"{"id":7}"#, byteLimit: 800)
        #expect(chunks == [#"{"id":7}"#])
    }

    @Test("빈 문자열은 조각이 없다")
    func emptyProducesNothing() {
        #expect(LoggingInterceptor.split("", byteLimit: 800).isEmpty)
    }

    @Test("긴 본문을 이어 붙이면 원문과 같다 — 잘리는 부분이 없다")
    func chunksRestoreOriginal() {
        let body = String(repeating: "가나다abc", count: 500)

        let chunks = LoggingInterceptor.split(body, byteLimit: 800)

        #expect(chunks.count > 1)
        #expect(chunks.joined() == body)
    }

    @Test("각 조각은 UTF-8 바이트 상한을 넘지 않는다")
    func chunksRespectByteLimit() {
        // 3바이트 한글이 상한을 걸치도록 만드는 케이스 — 문자 수로 자르면 여기서 상한을 넘긴다.
        let body = String(repeating: "한", count: 1000)

        let chunks = LoggingInterceptor.split(body, byteLimit: 800)

        #expect(chunks.allSatisfy { $0.utf8.count <= 800 })
        #expect(chunks.joined() == body)
    }

    @Test("한 글자가 상한보다 커도 잃어버리지 않는다")
    func oversizedCharacterSurvives() {
        let chunks = LoggingInterceptor.split("한글", byteLimit: 1)
        #expect(chunks == ["한", "글"])
    }
}
