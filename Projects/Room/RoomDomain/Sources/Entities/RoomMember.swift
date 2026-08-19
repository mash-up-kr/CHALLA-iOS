import Foundation

/// 방에 참여한 사람. `GET /rooms/{id}/users`의 한 줄에 대응한다.
/// 닉네임·사진은 서버 계약상 없을 수 있다 (프로필 미설정 사용자).
public struct RoomMember: Identifiable, Equatable, Sendable {

    public let id: Int64
    public let nickname: String?
    public let imageURL: URL?

    public init(id: Int64, nickname: String?, imageURL: URL?) {
        self.id = id
        self.nickname = nickname
        self.imageURL = imageURL
    }
}
