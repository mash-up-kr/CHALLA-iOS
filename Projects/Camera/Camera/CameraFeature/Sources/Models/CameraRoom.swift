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
