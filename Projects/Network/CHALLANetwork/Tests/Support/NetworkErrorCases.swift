import Foundation
@testable import CHALLANetwork

/// `NetworkError`는 연관값(`Response`·`any Error`) 때문에 `Equatable`이 아니라
/// `#expect(throws:)`만으로는 "어느 케이스인지"까지 단언할 수 없다.
/// 던져진 오류를 `#require(throws:)`로 받아 이 접근자로 케이스를 확인한다.
extension NetworkError {

    /// `.invalidRequest`면 사유, 아니면 nil.
    var invalidRequestReason: String? {
        guard case .invalidRequest(let reason) = self else { return nil }
        return reason
    }

    /// `.transport`면 감싼 원본 오류, 아니면 nil.
    var transportUnderlying: (any Error)? {
        guard case .transport(let underlying) = self else { return nil }
        return underlying
    }

    /// `.unacceptableStatusCode`면 상태 코드, 아니면 nil.
    var unacceptableStatusCode: Int? {
        guard case .unacceptableStatusCode(let statusCode, _) = self else { return nil }
        return statusCode
    }

    /// `.decoding`이면 함께 실린 응답, 아니면 nil.
    var decodingResponse: Response? {
        guard case .decoding(_, let response) = self else { return nil }
        return response
    }
}
