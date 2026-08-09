import Foundation

/// 프로필 이미지 업로드 인터페이스 (구현: `UserData`).
///
/// 서버가 아니라 스토리지에 직접 올리는 다단계 절차라 저장소와 분리한다 —
/// `UserRepository`는 이미 올라간 이미지의 URL만 받는다.
public protocol ProfileImageUploader: Sendable {
    /// 이미지를 올리고 프로필에 저장할 공개 URL을 돌려준다.
    /// 실패는 반드시 `UserError`로 정규화해 던진다.
    func upload(_ imageData: Data) async throws -> URL
}
