import ChatDomain
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
    /// 리액션 생성·삭제에 사용하는 서버 ID.
    static let chatID: Int64 = 77

    static func photo(id: String, reactions: [PhotoReaction] = []) -> Photo {
        // 스티커와 사용자별 선택 상태를 일치시킨다.
        let kinds = reactions.reduce(into: [String: Set<ReactionKind>]()) {
            $0[$1.userID, default: []].insert($1.kind)
        }
        return Photo(
            id: id,
            // 실제로 부르지 않는 주소라 파싱 실패 시 파일 URL로 떨어뜨린다 (force unwrap 금지 규칙).
            imageURL: URL(string: "https://example.com/\(id).jpg") ?? URL(fileURLWithPath: "/"),
            author: PhotoAuthor(id: "user-author", nickname: "나는야멋쟁이토마토"),
            capturedAt: Date(timeIntervalSince1970: 1_784_000_040),
            reactions: reactions,
            reactedKindsByUser: kinds
        )
    }

    /// 서버에서 조회한 리액션.
    static func reaction(_ kind: ReactionKind, by userID: String, chatID: Int64 = chatID) -> PhotoReaction {
        PhotoReaction(chatID: chatID, kind: kind, userID: userID)
    }
}

/// 의존성을 갈아끼운 TestStore를 만든다. 기본값은 "아무것도 못 하는" 구현이라
/// 각 테스트는 자기가 쓰는 UseCase만 넘긴다.
@MainActor
func makeTestStore(
    initialPhotoID: Photo.ID? = nil,
    photos: @escaping @Sendable (Int64) async throws -> [Photo] = { _ in [] },
    reactions: @escaping @Sendable (Int64, String) async throws -> PhotoReactions = { _, _ in PhotoReactions() },
    setReaction: @escaping @Sendable (Int64, String, ReactionKind) async throws -> Int64? = { _, _, _ in
        throw PhotoError.unknown
    },
    deleteReaction: @escaping @Sendable (Int64) async throws -> Void = { _ in
        throw PhotoError.unknown
    },
    sendChat: @escaping @Sendable (Int64, Int64?, String) async throws -> Void = { _, _, _ in
        throw ChatError.unknown
    },
    save: @escaping @Sendable (Photo) async throws -> Void = { _ in }
) -> TestStoreOf<PhotoDetailFeature> {
    TestStore(
        initialState: PhotoDetailFeature.State(
            roomID: Fixture.roomID,
            roomTitle: Fixture.roomTitle,
            currentUserID: Fixture.currentUserID,
            isPrinted: true,
            initialPhotoID: initialPhotoID
        )
    ) {
        PhotoDetailFeature()
    } withDependencies: {
        $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { room in try await photos(room) })
        $0.fetchPhotoReactionsUseCase = FetchPhotoReactionsUseCase(run: reactions)
        $0.setPhotoReactionUseCase = SetPhotoReactionUseCase(run: setReaction)
        $0.deletePhotoReactionUseCase = DeletePhotoReactionUseCase(run: deleteReaction)
        $0.sendChatUseCase = SendChatUseCase(run: sendChat)
        $0.savePhotoUseCase = SavePhotoUseCase(run: save)
        $0.uuid = .incrementing // 리액션 애니메이션(reactionBurst) id를 결정적으로
        $0.continuousClock = ImmediateClock() // 토스트 노출 시간을 기다리지 않는다
    }
}

/// 사진 목록을 이미 받아 첫 장을 펼친 상태에서 시작하는 Store.
@MainActor
func openedTestStore(
    photos loaded: [Photo],
    reactions: (@Sendable (Int64, String) async throws -> PhotoReactions)? = nil,
    setReaction: @escaping @Sendable (Int64, String, ReactionKind) async throws -> Int64? = { _, _, _ in
        throw PhotoError.unknown
    },
    deleteReaction: @escaping @Sendable (Int64) async throws -> Void = { _ in
        throw PhotoError.unknown
    },
    sendChat: @escaping @Sendable (Int64, Int64?, String) async throws -> Void = { _, _, _ in
        throw ChatError.unknown
    },
    save: @escaping @Sendable (Photo) async throws -> Void = { _ in }
) async -> TestStoreOf<PhotoDetailFeature> {
    // 지연 로딩: 펼친 사진의 리액션을 그 사진이 이미 가진 값으로 돌려준다(서버 = 픽스처와 동일 → 병합해도 사진은 그대로).
    let reactionsByID = Dictionary(uniqueKeysWithValues: loaded.map {
        ($0.id, PhotoReactions(stickers: $0.reactions, reactedKindsByUser: $0.reactedKindsByUser))
    })
    let store = makeTestStore(
        photos: { _ in loaded },
        reactions: reactions ?? { _, photoID in reactionsByID[photoID] ?? PhotoReactions() },
        setReaction: setReaction,
        deleteReaction: deleteReaction,
        sendChat: sendChat,
        save: save
    )
    await store.send(.view(.onAppear)) { $0.isLoading = true }
    await store.receive(\.photosResponse.success) {
        $0.isLoading = false
        $0.photos = IdentifiedArray(uniqueElements: loaded)
        $0.selectedPhotoID = loaded.first?.id
        // 펼친 첫 사진의 리액션을 지연 조회하기 시작한다.
        if let first = loaded.first?.id {
            $0.reactionsLoading.insert(first)
        }
    }
    if let first = loaded.first?.id {
        await store.receive(\.reactionsResponse) {
            $0.reactionsLoading.remove(first)
            $0.reactionsLoaded.insert(first)
            // 픽스처와 동일한 값이라 photos[first]는 그대로.
        }
    }
    return store
}
