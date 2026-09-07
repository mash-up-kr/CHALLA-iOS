import ChatDomain
import Foundation

/// 서버 공통 응답 껍데기 `{ success, message, data }`.
///
/// `PhotoData`·`RoomData`·`UserData`의 같은 타입을 복사한 것 — CHALLANetwork로 합치는 작업은
/// 이슈 #51이 진행 중이라 여기서 옮기지 않는다 (#51 머지 후 이 복사본을 지우고 갈아탄다).
struct BaseResponseDTO<Payload: Decodable & Sendable>: Decodable, Sendable {

    let success: Bool
    let message: String
    let data: Payload?

    func unwrap() throws -> Payload {
        guard success, let data else {
            throw ChatError.server(message: message)
        }
        return data
    }
}
