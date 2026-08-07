import Foundation
import UserDomain

struct BaseResponseDTO<Payload: Decodable & Sendable>: Decodable, Sendable {

    let success: Bool
    let message: String
    let data: Payload?

    func unwrap() throws -> Payload {
        guard success, let data else {
            throw UserError.server(message: message)
        }
        return data
    }

    func ensureSuccess() throws {
        guard success else {
            throw UserError.server(message: message)
        }
    }
}
