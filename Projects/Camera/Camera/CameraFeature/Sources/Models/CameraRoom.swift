import Foundation

/// 촬영 대상 방. 서버 연동 전이라 피처 안에 두고, RoomDomain이 생기면 그쪽 엔티티로 대체한다.
public struct CameraRoom: Equatable, Identifiable, Sendable {

    public let id: String
    public let name: String
    public let remainingCards: Int
    public let totalCards: Int

    public init(id: String, name: String, remainingCards: Int, totalCards: Int) {
        self.id = id
        self.name = name
        self.remainingCards = remainingCards
        self.totalCards = totalCards
    }

    public var cardsLevel: CameraCardsLevel {
        .init(remaining: remainingCards)
    }
}

/// 남은 장수를 어떤 색으로 보여줄지 결정하는 단계.
public enum CameraCardsLevel: Equatable, Sendable {
    case normal
    case low
    case unavailable

    /// 5장 이하부터 경고로 본다.
    static let lowThreshold = 5

    init(remaining: Int) {
        switch remaining {
        case ...0: self = .unavailable
        case ...Self.lowThreshold: self = .low
        default: self = .normal
        }
    }
}
