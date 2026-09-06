import ComposableArchitecture
import Foundation
import PhotoDetailFeature
import PhotoDomain
import Testing

@MainActor
@Suite("PhotoDetailFeature — 리액션")
struct PhotoDetailReactionTests {

    @Test("초기 조회 중 생성하면 이전 조회를 취소하고 서버 리액션을 다시 받는다")
    func refreshesAfterCreatingDuringInitialLoad() async {
        let clock = TestClock()
        let requests = LockIsolated(0)
        let other = Fixture.reaction(.heart, by: "other", chatID: 1)
        let created = Fixture.reaction(.fire, by: Fixture.currentUserID, chatID: 2)
        let server = Fixture.photo(id: "photo-1", reactions: [other, created])
        let store = makeTestStore(
            photos: { _ in [Fixture.photo(id: "photo-1")] },
            reactions: { _, _ in
                let request = requests.withValue { $0 += 1; return $0 }
                if request == 1 {
                    try await clock.sleep(for: .seconds(100))
                }
                return PhotoReactions(stickers: server.reactions, reactedKindsByUser: server.reactedKindsByUser)
            },
            setReaction: { _, _, _ in 2 }
        )
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.receive(\.photosResponse)
        await clock.advance()
        await store.send(.view(.reactionTapped(.fire)))
        await store.receive(\.reactionSucceeded)
        await store.receive(\.reactionsResponse)
        await store.finish()

        #expect(requests.value == 2)
        #expect(store.state.selectedPhoto?.reactions.map(\.chatID) == [1, 2])
        #expect(store.state.selectedPhoto?.reactions.last?.id == "local-\(UUID(0))")
        #expect(store.state.reactionsUpdating.isEmpty)
    }

    @Test("ID 없는 생성 성공 후 조회가 실패해도 스티커를 다시 눌러 복구할 수 있다")
    func retriesMissingChatIDAfterRefreshFailure() async {
        let requests = LockIsolated(0)
        let server = Fixture.photo(id: "photo-1", reactions: [
            Fixture.reaction(.fire, by: Fixture.currentUserID, chatID: 2)
        ])
        let store = await openedTestStore(
            photos: [Fixture.photo(id: "photo-1")],
            reactions: { _, _ in
                let request = requests.withValue { $0 += 1; return $0 }
                if request == 1 {
                    return PhotoReactions()
                }
                if request == 2 {
                    throw PhotoError.network
                }
                return PhotoReactions(stickers: server.reactions, reactedKindsByUser: server.reactedKindsByUser)
            },
            setReaction: { _, _, _ in nil }
        )
        store.exhaustivity = .off
        let localID = "local-\(UUID(0))"

        await store.send(.view(.reactionTapped(.fire)))
        await store.receive(\.reactionSucceeded)
        #expect(store.state.reactionsUpdating.contains("photo-1"))
        await store.receive(\.reactionsResponse)
        #expect(store.state.reactionsUpdating.isEmpty)
        #expect(store.state.reactionsNeedRefresh.contains("photo-1"))

        await store.send(.view(.stickerTapped(reactionID: localID)))
        await store.receive(\.reactionsResponse)
        await store.finish()
        #expect(store.state.selectedPhoto?.reaction(id: localID)?.chatID == 2)
        #expect(store.state.reactionsNeedRefresh.isEmpty)
        await store.send(.view(.stickerTapped(reactionID: localID)))
        #expect(store.state.drawer == .deleteReaction(photoID: "photo-1", reactionID: localID))
    }

    /// 낙관적으로 붙는 스티커. id는 `uuid` 의존성(`.incrementing`)이 정한다.
    private func localReaction(_ kind: ReactionKind, uuid index: Int = 0) -> PhotoReaction {
        PhotoReaction(id: "local-\(UUID(index))", kind: kind, userID: Fixture.currentUserID)
    }

    @Test("이모지를 누르면 스티커와 선택 상태를 반영하고 애니메이션을 재생한다")
    func addsStickerAndBurst() async {
        let target = Fixture.photo(id: "photo-1")
        let store = await openedTestStore(photos: [target], setReaction: { roomID, photoID, kind in
            #expect(roomID == Fixture.roomID)
            #expect(photoID == "photo-1")
            #expect(kind == .thumbsUp)
            return Fixture.chatID
        })

        // uuid는 스티커 id(0) → 애니메이션 id(1) 순으로 쓰인다.
        let added = localReaction(.thumbsUp, uuid: 0)
        await store.send(.view(.reactionTapped(.thumbsUp))) {
            $0.reactionsUpdating.insert("photo-1")
            $0.photos[id: "photo-1"] = target.addingReaction(added)
            $0.reactionBurst = PhotoDetailFeature.ReactionBurst(id: UUID(1), kind: .thumbsUp)
        }
        await store.receive(\.reactionSucceeded) {
            $0.reactionsUpdating.remove("photo-1")
            $0.photos[id: "photo-1"] = target.addingReaction(added).attachingChatID(Fixture.chatID, to: added.id)
        }
    }

    @Test("이미 남긴 종류를 다시 누르면 아무 일도 하지 않는다")
    func ignoresAlreadyReactedKind() async {
        let existing = Fixture.reaction(.heart, by: Fixture.currentUserID, chatID: 1)
        let target = Fixture.photo(id: "photo-1", reactions: [existing])
        // 기본 setReaction은 호출되면 던진다 — 여기선 아예 호출되지 않아야 한다.
        let store = await openedTestStore(photos: [target])

        await store.send(.view(.reactionTapped(.heart)))
    }

    @Test("다른 종류는 개수 제한 없이 계속 붙는다")
    func addsStickerForEachKind() async {
        let existing = Fixture.reaction(.heart, by: Fixture.currentUserID, chatID: 1)
        let target = Fixture.photo(id: "photo-1", reactions: [existing])
        let store = await openedTestStore(photos: [target], setReaction: { _, _, kind in
            #expect(kind == .fire)
            return 2
        })

        let added = localReaction(.fire, uuid: 0)
        await store.send(.view(.reactionTapped(.fire))) {
            $0.reactionsUpdating.insert("photo-1")
            $0.photos[id: "photo-1"] = target.addingReaction(added)
            $0.reactionBurst = PhotoDetailFeature.ReactionBurst(id: UUID(1), kind: .fire)
        }
        await store.receive(\.reactionSucceeded) {
            $0.reactionsUpdating.remove("photo-1")
            $0.photos[id: "photo-1"] = target.addingReaction(added).attachingChatID(2, to: added.id)
        }
        #expect(store.state.photos[id: "photo-1"]?.reactions.count == 2)
    }

    @Test("전송에 실패하면 방금 붙인 스티커만 떼고 얼럿을 띄운다")
    func rollsBackFailedSticker() async {
        let existing = Fixture.reaction(.heart, by: Fixture.currentUserID, chatID: 1)
        let target = Fixture.photo(id: "photo-1", reactions: [existing])
        let store = await openedTestStore(photos: [target], setReaction: { _, _, _ in
            throw PhotoError.network
        })

        let added = localReaction(.thumbsUp, uuid: 0)
        await store.send(.view(.reactionTapped(.thumbsUp))) {
            $0.reactionsUpdating.insert("photo-1")
            $0.photos[id: "photo-1"] = target.addingReaction(added)
            $0.reactionBurst = PhotoDetailFeature.ReactionBurst(id: UUID(1), kind: .thumbsUp)
        }
        await store.receive(\.reactionFailed) {
            $0.reactionsUpdating.remove("photo-1")
            $0.photos[id: "photo-1"] = target
            $0.alert = AlertState {
                TextState("리액션을 남기지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.network.userMessage)
            }
        }
    }
}
