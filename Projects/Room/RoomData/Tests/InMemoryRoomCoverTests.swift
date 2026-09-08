@testable import RoomData
import Foundation
import RoomDomain
import Testing

@Suite("InMemoryRoomRepository — 커버")
struct InMemoryRoomRepositoryCoverTests {

    private static let card = RoomCard.previewShooting
    private static let imageURL = URL(string: "https://example.com/cover/1.jpg")!

    @Test("옵션은 주입한 값을 그대로 돌려주고 기본은 preview다")
    func returnsInjectedOptions() async throws {
        let defaulted = InMemoryRoomRepository(cards: [Self.card])
        let custom = InMemoryRoomRepository(cards: [Self.card], coverOptions: .empty)

        #expect(try await defaulted.coverOptions() == .preview)
        #expect(try await custom.coverOptions() == .empty)
    }

    @Test("스티커·색 id를 옵션에서 찾아 조립한 커버로 그 방을 갱신한다")
    func updateCoverAssemblesFromOptions() async throws {
        let repository = InMemoryRoomRepository(cards: [Self.card])

        try await repository.updateCover(roomID: Self.card.id, imageURL: Self.imageURL, stickerID: 3, colorID: 5)

        let updated = try #require(try await repository.rooms().first)
        #expect(updated.room.cover.imageURL == Self.imageURL)
        #expect(updated.room.cover.sticker?.id == 3)
        #expect(updated.room.cover.sticker?.color == RoomCoverOptions.preview.colors[4])
        #expect(updated.room.withCover(.none) == Self.card.room)
        #expect(updated.memberCount == Self.card.memberCount)
    }

    @Test("색 id가 없으면 팔레트 첫 색을 쓴다")
    func updateCoverFallsBackToFirstColor() async throws {
        let repository = InMemoryRoomRepository(cards: [Self.card])

        try await repository.updateCover(roomID: Self.card.id, imageURL: nil, stickerID: 2, colorID: nil)

        let cover = try #require(try await repository.rooms().first?.room.cover)
        let expected = RoomCoverOptions.preview.stickers[1].sticker(color: RoomCoverOptions.preview.colors[0])
        #expect(cover.sticker == expected)
    }

    @Test("세 값을 전부 nil로 보내면 빈 커버가 된다")
    func updateCoverClears() async throws {
        let repository = InMemoryRoomRepository(cards: [Self.card])
        try await repository.updateCover(roomID: Self.card.id, imageURL: Self.imageURL, stickerID: 1, colorID: 1)

        try await repository.updateCover(roomID: Self.card.id, imageURL: nil, stickerID: nil, colorID: nil)

        #expect(try await repository.rooms().first?.room.cover == RoomCover.none)
    }

    @Test("옵션에 없는 스티커·색 id는 .unknown을 던진다", arguments: [(99 as Int64?, 1 as Int64?), (1, 99)])
    func unknownOptionIDThrows(stickerID: Int64?, colorID: Int64?) async {
        let repository = InMemoryRoomRepository(cards: [Self.card])

        await #expect(throws: RoomError.unknown) {
            try await repository.updateCover(roomID: Self.card.id, imageURL: nil, stickerID: stickerID, colorID: colorID)
        }
    }

    @Test("없는 방은 .roomNotFound를 던진다")
    func unknownRoomThrows() async {
        let repository = InMemoryRoomRepository(cards: [Self.card])

        await #expect(throws: RoomError.roomNotFound) {
            try await repository.updateCover(roomID: -999, imageURL: nil, stickerID: 1, colorID: 1)
        }
    }

    @Test("failure를 심으면 옵션 조회·커버 수정 모두 그 오류를 던진다")
    func injectedFailurePropagates() async {
        let repository = InMemoryRoomRepository(cards: [Self.card], failure: .network)

        await #expect(throws: RoomError.network) {
            _ = try await repository.coverOptions()
        }
        await #expect(throws: RoomError.network) {
            try await repository.updateCover(roomID: Self.card.id, imageURL: nil, stickerID: 1, colorID: 1)
        }
    }
}

@Suite("InMemoryRoomCoverImageUploader")
struct InMemoryRoomCoverImageUploaderTests {

    @Test("업로드 없이 고정 형태의 URL을 돌려주고 호출마다 다르다")
    func returnsFixedShapeURL() async throws {
        let uploader = InMemoryRoomCoverImageUploader()

        let first = try await uploader.upload(Data([0x01]))
        let second = try await uploader.upload(Data([0x01]))

        #expect(first.absoluteString.hasPrefix("https://example.com/cover/"))
        #expect(first.pathExtension == "jpg")
        #expect(first != second)
    }

    @Test("failure를 심으면 그 오류를 던진다")
    func injectedFailurePropagates() async {
        let uploader = InMemoryRoomCoverImageUploader(failure: .server(message: "업로드 실패"))

        await #expect(throws: RoomError.server(message: "업로드 실패")) {
            _ = try await uploader.upload(Data())
        }
    }
}
