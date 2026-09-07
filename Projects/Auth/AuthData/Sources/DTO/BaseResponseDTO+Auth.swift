import AuthDomain
import CHALLANetwork

/// 공용 `BaseResponseDTO`의 실패를 AuthData 도메인 오류로 묶는다.
extension BaseResponseDTO {

    /// 실패 시 `AuthError.server(message:)`를 던진다.
    func unwrap() throws -> Payload {
        try unwrap(orServerError: AuthError.server(message:))
    }

    /// 실패 시 `AuthError.server(message:)`를 던진다 (페이로드 무시).
    func ensureSuccess() throws {
        try ensureSuccess(orServerError: AuthError.server(message:))
    }
}
