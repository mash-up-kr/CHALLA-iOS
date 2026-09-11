import Foundation

/// `GET /api/v1/photos` 응답의 한 페이지. 서버가 `hasNext`로 다음 페이지 존재를 알린다.
struct ListPhotosSliceResponseDTO: Decodable, Sendable {

    let photos: [ListPhotosResponseDTO]
    let hasNext: Bool
}

/// 목록 응답의 사진 한 장. 리액션은 목록에 실리지 않는다 — 상세(`chats`)에만 있다.
struct ListPhotosResponseDTO: Decodable, Sendable {

    let id: Int64
    /// 인화 전이면 null이 올 수 있다. 표시할 URL이 없으면 도메인 변환에서 제외한다.
    let imageUrl: String?
    /// 목록·필름이 쓸 축소본 주소. 축소본이 없는 사진(이 기능 이전에 올라간 것)은 null이고,
    /// 서버가 대신 채워 주지 않으므로 폴백은 앱이 한다 (``Photo/previewURL``).
    let thumbnailImageUrl: String?
    let userNickname: String
    let userProfileImageUrl: String?
    /// 서버가 타임존 없이 UTC로 내려주는 문자열 — `ServerDate`로 파싱한다.
    let createdAt: String
}
