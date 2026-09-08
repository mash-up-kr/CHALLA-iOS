import Foundation

struct RoomCoverDTO: Decodable, Sendable {
    let coverImageUrl: String?
    let sticker: StickerDTO?
}

struct StickerDTO: Decodable, Sendable {
    let id: Int64
    let imageUrl: String? // 앱은 쓰지 않는 값 — null이 와도 목록 디코딩이 깨지지 않게
    let color: ColorDTO
}

struct ColorDTO: Decodable, Sendable {
    let id: Int64
    let name: String
    let hex: String
}

/// 선택지 응답의 스티커 — 커버 응답의 `StickerDTO`와 달리 `color`가 없다 (스웨거는 필수로 적혀 있지만 실제 응답에 없다).
struct StickerOptionDTO: Decodable, Sendable {
    let id: Int64
    let imageUrl: String?
}

struct CoverOptionsResponseDTO: Decodable, Sendable {

    let room: Payload

    struct Payload: Decodable, Sendable {
        let stickers: [StickerOptionDTO]
        let colors: [ColorDTO]
    }
}
