import Foundation

/// 사진을 찍은 사람. `UserDomain` 프로필과 별개로, 촬영 시점의 정보를 사진에 저장한다.
public struct PhotoAuthor: Sendable, Equatable {

    public let id: String
    public let nickname: String
    public let avatarURL: URL?

    public init(id: String, nickname: String, avatarURL: URL? = nil) {
        self.id = id
        self.nickname = nickname
        self.avatarURL = avatarURL
    }
}
