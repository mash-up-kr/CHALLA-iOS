@testable import CHALLANetwork
import Foundation
import Testing

@Suite("BaseResponseDTO")
struct BaseResponseDTOTests {

    private struct Payload: Decodable, Sendable, Equatable {
        let value: String
    }

    /// 실패 시 호출 모듈이 넘길 오류를 흉내 낸다 (message가 그대로 실리는지 검증용).
    private enum TestError: Error, Equatable {
        case failed(String)
    }

    private func decode<P: Decodable & Sendable>(_: P.Type, from json: String) throws -> BaseResponseDTO<P> {
        try JSONDecoder().decode(BaseResponseDTO<P>.self, from: Data(json.utf8))
    }

    @Test("success + data가 있으면 unwrap이 payload를 돌려준다")
    func unwrapSuccess() throws {
        let dto = try decode(Payload.self, from: #"{"success": true, "message": "ok", "data": {"value": "hi"}}"#)

        let payload = try dto.unwrap(orServerError: TestError.failed)

        #expect(payload == Payload(value: "hi"))
    }

    @Test("success=false면 클로저가 만든 오류를 서버 메시지와 함께 던진다")
    func unwrapServerFailure() throws {
        let dto = try decode(Payload.self, from: #"{"success": false, "message": "실패했어요", "data": null}"#)

        #expect(throws: TestError.failed("실패했어요")) {
            _ = try dto.unwrap(orServerError: TestError.failed)
        }
    }

    @Test("success=true여도 data가 없으면 unwrap은 오류를 던진다")
    func unwrapMissingData() throws {
        let dto = try decode(Payload.self, from: #"{"success": true, "message": "ok", "data": null}"#)

        #expect(throws: TestError.failed("ok")) {
            _ = try dto.unwrap(orServerError: TestError.failed)
        }
    }

    @Test("ensureSuccess는 data가 null이어도 success면 통과한다")
    func ensureSuccessIgnoresPayload() throws {
        let dto = try decode(EmptyResponseDTO.self, from: #"{"success": true, "message": "ok", "data": null}"#)

        try dto.ensureSuccess(orServerError: TestError.failed) // throw되면 테스트 실패
    }

    @Test("ensureSuccess는 success=false면 오류를 던진다")
    func ensureSuccessFailure() throws {
        let dto = try decode(EmptyResponseDTO.self, from: #"{"success": false, "message": "만료됐어요", "data": null}"#)

        #expect(throws: TestError.failed("만료됐어요")) {
            try dto.ensureSuccess(orServerError: TestError.failed)
        }
    }
}
