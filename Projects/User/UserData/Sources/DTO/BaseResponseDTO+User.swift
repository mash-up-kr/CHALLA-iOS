import CHALLANetwork
import UserDomain

/// 공용 `BaseResponseDTO`의 실패를 UserData 도메인 오류로 묶는다.
extension BaseResponseDTO {

    /// 실패 시 `UserError.server(message:)`를 던진다.
    func unwrap() throws -> Payload {
        try unwrap(orServerError: UserError.server(message:))
    }

    /// 실패 시 `UserError.server(message:)`를 던진다 (페이로드 무시).
    func ensureSuccess() throws {
        try ensureSuccess(orServerError: UserError.server(message:))
    }
}
