import CHALLANetwork
import RoomDomain

/// 공용 `BaseResponseDTO`의 실패를 RoomData 도메인 오류로 묶는다.
extension BaseResponseDTO {

    /// 실패 시 `RoomError.server(message:)`를 던진다.
    func unwrap() throws -> Payload {
        try unwrap(orServerError: RoomError.server(message:))
    }
}
