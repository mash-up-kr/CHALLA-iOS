import Foundation

/// 뷰파인더에 입히는 필름 필터. 서버가 목록을 내려주기 전까지는 데모/프리뷰가 직접 채운다.
public struct CameraFilter: Equatable, Identifiable, Sendable {

    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
