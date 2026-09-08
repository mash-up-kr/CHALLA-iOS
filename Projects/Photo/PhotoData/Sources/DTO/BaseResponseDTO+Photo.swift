import CHALLANetwork
import PhotoDomain

/// 공용 `BaseResponseDTO`의 실패를 PhotoData 도메인 오류로 묶는다.
extension BaseResponseDTO {

    /// 실패 시 `PhotoError.server(message:)`를 던진다.
    func unwrap() throws -> Payload {
        try unwrap(orServerError: PhotoError.server(message:))
    }
}
