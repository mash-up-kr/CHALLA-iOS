@testable import RoomDetailFeature
import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import Testing

/// 촬영을 마치고 들어온 경로에서만 방금 올린 사진을 잠깐 강조한다.
/// 상세·사진 조회 자체는 `RoomDetailFeatureTests`가 본다.
@MainActor
@Suite("RoomDetailFeature 촬영본 강조")
struct RoomDetailNewestPhotoHighlightTests {

    private nonisolated static let detail = RoomDetail(
        room: .previewShooting,
        invitationCode: "1928121",
        members: []
    )

    /// 마지막 장이 방금 올린 사진이다 — 강조는 이 한 장에만 걸린다.
    private nonisolated static let photos: [Photo] = (1 ... 2).compactMap { number in
        URL(string: "https://img.example.com/\(number).jpg").map { url in
            Photo(
                id: "\(number)",
                imageURL: url,
                author: PhotoAuthor(id: "u1", nickname: "찰나둥이"),
                capturedAt: Date(timeIntervalSince1970: 0)
            )
        }
    }

    private static func makeStore(
        highlightsNewestPhoto: Bool,
        clock: TestClock<Duration>
    ) -> TestStoreOf<RoomDetailFeature> {
        TestStore(
            initialState: RoomDetailFeature.State(
                room: .previewShooting,
                highlightsNewestPhoto: highlightsNewestPhoto
            )
        ) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in detail })
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in photos })
            $0.shouldShowInviteGuideUseCase.run = { false }
            $0.continuousClock = clock
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
    }

    @Test("촬영을 마치고 들어오면 마지막 사진을 1초간 강조했다가 거둔다")
    func highlightsNewestPhotoAfterCapture() async {
        let clock = TestClock()
        let store = Self.makeStore(highlightsNewestPhoto: true, clock: clock)

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
            $0.photosLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.hasCheckedInviteGuide = true
        }
        await store.receive(\.photosResponse.success) {
            $0.photosLoad = .loaded
            $0.photos = Self.photos
            $0.highlightsNewestPhoto = false // 한 번만 강조한다
            $0.highlightedPhotoID = "2"
        }

        await clock.advance(by: .seconds(1))
        await store.receive(\.newestPhotoHighlightElapsed) {
            $0.highlightedPhotoID = nil
        }
    }

    @Test("평소 진입에서는 강조하지 않는다")
    func doesNotHighlightOnNormalEntry() async {
        let clock = TestClock()
        let store = Self.makeStore(highlightsNewestPhoto: false, clock: clock)

        await store.send(.view(.task)) {
            $0.detailLoad = .loading
            $0.photosLoad = .loading
        }
        await store.receive(\.detailResponse.success) {
            $0.detailLoad = .loaded
            $0.detail = Self.detail
            $0.hasCheckedInviteGuide = true
        }
        await store.receive(\.photosResponse.success) {
            $0.photosLoad = .loaded
            $0.photos = Self.photos
        }
    }
}
