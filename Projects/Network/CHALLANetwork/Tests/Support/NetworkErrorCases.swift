@testable import CHALLANetwork
import Foundation

/// `NetworkError`는 연관값(`Response`·`any Error`) 때문에 `Equatable`이 아니라
/// `#expect(throws:)`만으로는 "어느 케이스인지"까지 단언할 수 없다.
/// 던져진 오류를 `#require(throws:)`로 받아 이 접근자로 케이스를 확인한다.
extension NetworkError {

    var invalidRequestReason: String? {
        guard case let .invalidRequest(reason) = self else { return nil }
        return reason
    }

    var transportUnderlying: (any Error)? {
        guard case let .transport(underlying) = self else { return nil }
        return underlying
    }

    var unacceptableStatusCode: Int? {
        guard case let .unacceptableStatusCode(statusCode, _) = self else { return nil }
        return statusCode
    }

    var decodingResponse: Response? {
        guard case let .decoding(_, response) = self else { return nil }
        return response
    }
}
