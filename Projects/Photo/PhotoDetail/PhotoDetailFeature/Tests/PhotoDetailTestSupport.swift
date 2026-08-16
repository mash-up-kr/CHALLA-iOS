import ComposableArchitecture
import Foundation
import PhotoDetailFeature
import PhotoDomain

/// 테스트가 공유하는 고정값과 사진 만들기 헬퍼.
enum Fixture {

    static let roomID: Int64 = -1
    static let roomTitle = "해피하우스 강릉 여행"
    /// 화면을 보는 사람 = 리액션을 남기는 사람.
    static let currentUserID = "user-me"

    static func photo(id: String, reactions: [PhotoReaction] = []) -> Photo {
        Photo(
            id: id,
            // 실제로 부르지 않는 주소라 파싱 실패 시 파일 URL로 떨어뜨린다 (force unwrap 금지 규칙).
            imageURL: URL(string: "https://example.com/\(id).jpg") ?? URL(fileURLWithPath: "/"),
            author: PhotoAuthor(id: "user-author", nickname: "나는야멋쟁이토마토"),
            capturedAt: Date(timeIntervalSince1970: 1_784_000_040),
            reactions: reactions
        )
    }

    static func reaction(_ kind: ReactionKind, by userID: String) -> PhotoReaction {
        PhotoReaction(kind: kind, userID: userID)
    }

    static func request(_ kind: ReactionKind, photoID: String) -> PhotoDetailFeature.ReactionRequest {
        PhotoDetailFeature.ReactionRequest(photoID: photoID, kind: kind)
    }
}

/// 의존성을 갈아끼운 TestStore를 만든다. 기본값은 "아무것도 못 하는" 구현이라
/// 각 테스트는 자기가 쓰는 UseCase만 넘긴다.
@MainActor
func makeTestStore(
    initialPhotoID: Photo.ID? = nil,
    photos: @escaping @Sendable (String) async throws -> [Photo] = { _ in [] },
    setReaction: @escaping @Sendable (String, ReactionKind, Bool) async throws -> Photo = { _, _, _ in
        throw PhotoError.unknown
    },
    save: @escaping @Sendable (Photo) async throws -> Void = { _ in }
) -> TestStoreOf<PhotoDetailFeature> {
    TestStore(
        initialState: PhotoDetailFeature.State(
            roomID: Fixture.roomID,
            roomTitle: Fixture.roomTitle,
            currentUserID: Fixture.currentUserID,
            initialPhotoID: initialPhotoID
        )
    ) {
        PhotoDetailFeature()
    } withDependencies: {
        $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: photos)
        $0.setPhotoReactionUseCase = SetPhotoReactionUseCase(run: setReaction)
        $0.savePhotoUseCase = SavePhotoUseCase(run: save)
    }
}

/// 사진 목록을 이미 받아 첫 장을 펼친 상태에서 시작하는 Store.
@MainActor
func openedTestStore(
    photos loaded: [Photo],
    setReaction: @escaping @Sendable (String, ReactionKind, Bool) async throws -> Photo = { _, _, _ in
        throw PhotoError.unknown
    },
    save: @escaping @Sendable (Photo) async throws -> Void = { _ in }
) async -> TestStoreOf<PhotoDetailFeature> {
    let store = makeTestStore(photos: { _ in loaded }, setReaction: setReaction, save: save)
    await store.send(.view(.onAppear)) { $0.isLoading = true }
    await store.receive(\.photosResponse.success) {
        $0.isLoading = false
        $0.photos = IdentifiedArray(uniqueElements: loaded)
        $0.selectedPhotoID = loaded.first?.id
    }
    return store
}
