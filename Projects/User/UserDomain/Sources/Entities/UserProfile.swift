import Foundation

/// 서버에 저장된 유저 프로필.
public struct UserProfile: Sendable, Equatable {
    public let id: Int64
    /// 프로필 최초 설정 전에는 서버가 닉네임을 내려주지 않는다.
    public let nickname: String?
    /// 서버가 돌려주는 프로필 이미지 URL. 미설정이면 nil.
    public let imageURL: URL?

    /// 프로필 최초 설정을 마쳤는지 — 앱 진입 시 첫 화면을 고르는 기준.
    public var isProfileCompleted: Bool {
        nickname != nil
    }

    public init(id: Int64, nickname: String? = nil, imageURL: URL? = nil) {
        self.id = id
        self.nickname = nickname
        self.imageURL = imageURL
    }
}
