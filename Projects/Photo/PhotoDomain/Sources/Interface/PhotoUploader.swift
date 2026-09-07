import Foundation

/// 촬영한 사진을 방에 올리는 인터페이스 (구현: `PhotoData`).
///
/// 서버가 아니라 스토리지에 직접 올리는 다단계 절차(서명 URL 발급 → 스토리지 PUT → 완료 통보)라
/// 저장소와 분리한다 — `ProfileImageUploader`와 같은 구조다.
public protocol PhotoUploader: Sendable {

    /// 사진을 올리고 그 방의 남은 장수를 돌려준다.
    /// 실패는 반드시 `PhotoError`로 정규화해 던진다.
    /// - Parameters:
    ///   - jpegData: 촬영본 JPEG. 인코딩은 호출부가 끝내서 넘긴다.
    ///     서버의 파일 크기 상한 준수는 구현 책임이다 — 호출부는 압축을 신경 쓰지 않는다.
    ///   - roomID: 업로드할 방의 서버 식별자 (`Room.id`와 같은 값).
    ///   - filterName: 촬영에 쓴 필터의 `CameraFilter.name`.
    func upload(jpegData: Data, roomID: Int64, filterName: String) async throws -> Int
}
