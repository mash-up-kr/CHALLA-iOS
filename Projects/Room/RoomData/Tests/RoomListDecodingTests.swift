@testable import RoomData
import Foundation
import RoomDomain
import Testing

/// 실제 서버 응답을 사용한 디코딩 회귀 테스트.
@Suite("방 목록 응답 디코딩")
struct RoomListDecodingTests {

    @Test("실서버 응답(cover 포함)을 그대로 디코딩한다")
    func decodesRealServerPayload() async throws {
        // 2026-09-06 실서버 응답 발췌. 앱이 아직 안 쓰는 `cover`가 함께 온다.
        let json = """
        { "success": true, "message": "OK", "data": { "rooms": [
          { "id": 47, "status": "PHOTO_PRINT_COMPLETED", "title": "ㅎㅎ", "memberCount": 1,
            "totalPhotoCount": 24, "remainedPhotoCount": 0,
            "thumbnailImageUrls": ["https://cdn.test/a.jpg", "https://cdn.test/b.jpg"],
            "cover": { "coverImageUrl": null, "sticker": { "id": 6,
              "imageUrl": "https://cdn.test/6.svg",
              "color": { "id": 2, "name": "pink", "hex": "#FF1887" } } },
            "photoPrintCompletedAt": "2026-08-31T18:12:16.017607",
            "photoPrintCompletionCheckedAt": "2026-09-05T11:29:02.552734",
            "createdAt": "2026-08-31T15:11:33.927327",
            "expiresAt": "2026-09-30T15:11:33.927332" },
          { "id": 17, "status": "SHOOTING", "title": "하이", "memberCount": 1,
            "totalPhotoCount": 48, "remainedPhotoCount": 23,
            "thumbnailImageUrls": ["https://cdn.test/c.jpg"],
            "cover": { "coverImageUrl": null, "sticker": null },
            "photoPrintCompletedAt": null, "photoPrintCompletionCheckedAt": null,
            "createdAt": "2026-08-13T15:05:49.009718",
            "expiresAt": "2026-09-12T15:05:49.00974" }
        ] } }
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultRoomRepository(client: client)

        let cards = try await repository.rooms()

        #expect(cards.map(\.room.id) == [47, 17])
        #expect(cards.first?.room.status == .printed)
        #expect(cards.first?.memberCount == 1)
        #expect(cards.first?.thumbnailURLs.count == 2)
        // 촬영 중 방은 인화 시각이 전부 null이다.
        #expect(cards.last?.room.status == .shooting)
        #expect(cards.last?.room.photoPrintCompletedAt == nil)
        #expect(cards.last?.photoPrintCompletionCheckedAt == nil)
    }
}
