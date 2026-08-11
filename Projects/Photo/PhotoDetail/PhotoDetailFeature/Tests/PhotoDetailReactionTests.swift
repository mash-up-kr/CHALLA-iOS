import ComposableArchitecture
import PhotoDetailFeature
import PhotoDomain
import Testing

@MainActor
@Suite("PhotoDetailFeature — 리액션")
struct PhotoDetailReactionTests {

    @Test("리액션은 서버 응답을 기다리지 않고 먼저 붙는다")
    func appliesReactionOptimistically() async {
        let target = Fixture.photo(id: "photo-1")
        let confirmed = Fixture.photo(
            id: "photo-1",
            reactions: [Fixture.reaction(.clap, by: "user-server")]
        )
        let store = await openedTestStore(photos: [target], setReaction: { photoID, kind, isOn in
            #expect(photoID == "photo-1")
            #expect(kind == .clap)
            #expect(isOn)
            return confirmed
        })

        await store.send(.view(.reactionTapped(.clap))) {
            $0.inFlightReactions = [Fixture.request(.clap, photoID: "photo-1")]
            $0.photos[id: "photo-1"] = target.settingReaction(.clap, by: Fixture.currentUserID, isOn: true)
        }
        await store.receive(\.reactionSucceeded) {
            $0.inFlightReactions = []
            $0.photos[id: "photo-1"] = confirmed
        }
    }

    @Test("이미 남긴 리액션을 누르면 끄는 요청을 보낸다")
    func turnsReactionOff() async {
        let mine = Fixture.reaction(.heart, by: Fixture.currentUserID)
        let target = Fixture.photo(id: "photo-1", reactions: [mine])
        let confirmed = Fixture.photo(id: "photo-1")
        let store = await openedTestStore(photos: [target], setReaction: { _, _, isOn in
            #expect(!isOn)
            return confirmed
        })

        await store.send(.view(.reactionTapped(.heart))) {
            $0.inFlightReactions = [Fixture.request(.heart, photoID: "photo-1")]
            $0.photos[id: "photo-1"] = target.settingReaction(.heart, by: Fixture.currentUserID, isOn: false)
        }
        await store.receive(\.reactionSucceeded) {
            $0.inFlightReactions = []
            $0.photos[id: "photo-1"] = confirmed
        }
    }

    @Test("리액션이 실패하면 누르기 전으로 되돌리고 얼럿을 띄운다")
    func rollsBackFailedReaction() async {
        let target = Fixture.photo(id: "photo-1")
        let store = await openedTestStore(photos: [target], setReaction: { _, _, _ in
            throw PhotoError.network
        })

        await store.send(.view(.reactionTapped(.heart))) {
            $0.inFlightReactions = [Fixture.request(.heart, photoID: "photo-1")]
            $0.photos[id: "photo-1"] = target.settingReaction(.heart, by: Fixture.currentUserID, isOn: true)
        }
        await store.receive(\.reactionFailed) {
            $0.inFlightReactions = []
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

    @Test("되돌릴 때 그 사이 들어온 남의 리액션은 살려 둔다")
    func rollbackKeepsConcurrentChanges() async {
        let target = Fixture.photo(id: "photo-1")
        let othersReaction = Fixture.reaction(.medal, by: "user-other")
        // 재조회가 먼저 도착하도록 실패를 붙잡아 둔다.
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        let store = await openedTestStore(photos: [target], setReaction: { _, _, _ in
            await stream.first { _ in true }
            throw PhotoError.network
        })

        await store.send(.view(.reactionTapped(.heart))) {
            $0.inFlightReactions = [Fixture.request(.heart, photoID: "photo-1")]
            $0.photos[id: "photo-1"] = target.settingReaction(.heart, by: Fixture.currentUserID, isOn: true)
        }

        // 요청이 떠 있는 동안 재조회가 끝나 남의 리액션이 들어왔다.
        let refreshed = Fixture.photo(
            id: "photo-1",
            reactions: [othersReaction, Fixture.reaction(.heart, by: Fixture.currentUserID)]
        )
        await store.send(.photosResponse(.success([refreshed]))) {
            $0.photos = [refreshed]
        }

        continuation.yield()
        continuation.finish()
        await store.receive(\.reactionFailed) {
            $0.inFlightReactions = []
            // 내 리액션만 지워지고 남의 리액션은 남는다.
            $0.photos[id: "photo-1"] = Fixture.photo(id: "photo-1", reactions: [othersReaction])
            $0.alert = AlertState {
                TextState("리액션을 남기지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.network.userMessage)
            }
        }
    }

    @Test("응답을 기다리는 동안 같은 자리를 다시 눌러도 요청이 겹치지 않는다")
    func ignoresRepeatedTapWhileInFlight() async {
        let target = Fixture.photo(id: "photo-1")
        let confirmed = Fixture.photo(
            id: "photo-1",
            reactions: [Fixture.reaction(.clap, by: Fixture.currentUserID)]
        )
        let callCount = LockIsolated(0)
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        let store = await openedTestStore(photos: [target], setReaction: { _, _, _ in
            callCount.withValue { $0 += 1 }
            await stream.first { _ in true }
            return confirmed
        })

        await store.send(.view(.reactionTapped(.clap))) {
            $0.inFlightReactions = [Fixture.request(.clap, photoID: "photo-1")]
            $0.photos[id: "photo-1"] = target.settingReaction(.clap, by: Fixture.currentUserID, isOn: true)
        }
        await store.send(.view(.reactionTapped(.clap)))

        continuation.yield()
        continuation.finish()
        await store.receive(\.reactionSucceeded) {
            $0.inFlightReactions = []
            $0.photos[id: "photo-1"] = confirmed
        }
        #expect(callCount.value == 1)
    }

    @Test("다른 사진으로 넘어가 리액션을 남겨도 앞선 요청은 끊기지 않는다")
    func keepsEarlierRequestWhenMovingOn() async {
        let first = Fixture.photo(id: "photo-1")
        let second = Fixture.photo(id: "photo-2")
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        let store = await openedTestStore(photos: [first, second], setReaction: { photoID, _, _ in
            // 첫 사진의 요청만 붙잡아 둔다.
            if photoID == "photo-1" {
                await stream.first { _ in true }
                throw PhotoError.network
            }
            return second.settingReaction(.heart, by: Fixture.currentUserID, isOn: true)
        })

        await store.send(.view(.reactionTapped(.clap))) {
            $0.inFlightReactions = [Fixture.request(.clap, photoID: "photo-1")]
            $0.photos[id: "photo-1"] = first.settingReaction(.clap, by: Fixture.currentUserID, isOn: true)
        }

        await store.send(.view(.photoSelected("photo-2"))) { $0.selectedPhotoID = "photo-2" }
        await store.send(.view(.reactionTapped(.heart))) {
            $0.inFlightReactions.insert(Fixture.request(.heart, photoID: "photo-2"))
            $0.photos[id: "photo-2"] = second.settingReaction(.heart, by: Fixture.currentUserID, isOn: true)
        }
        await store.receive(\.reactionSucceeded) {
            $0.inFlightReactions.remove(Fixture.request(.heart, photoID: "photo-2"))
        }

        // 앞선 사진의 요청은 취소되지 않았으므로 실패가 도착해 되돌려진다.
        continuation.yield()
        continuation.finish()
        await store.receive(\.reactionFailed) {
            $0.inFlightReactions = []
            $0.photos[id: "photo-1"] = first
            $0.alert = AlertState {
                TextState("리액션을 남기지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.network.userMessage)
            }
        }
    }

    @Test("응답이 늦게 왔는데 그 사진이 목록에서 사라졌으면 되살리지 않는다")
    func doesNotResurrectDeletedPhoto() async {
        let target = Fixture.photo(id: "photo-1")
        let confirmed = Fixture.photo(
            id: "photo-1",
            reactions: [Fixture.reaction(.clap, by: Fixture.currentUserID)]
        )
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        let store = await openedTestStore(photos: [target], setReaction: { _, _, _ in
            await stream.first { _ in true }
            return confirmed
        })

        await store.send(.view(.reactionTapped(.clap))) {
            $0.inFlightReactions = [Fixture.request(.clap, photoID: "photo-1")]
            $0.photos[id: "photo-1"] = target.settingReaction(.clap, by: Fixture.currentUserID, isOn: true)
        }

        // 재조회 결과 그 사진이 사라졌다.
        await store.send(.photosResponse(.success([]))) {
            $0.photos = []
            $0.selectedPhotoID = nil
        }

        continuation.yield()
        continuation.finish()
        await store.receive(\.reactionSucceeded) {
            $0.inFlightReactions = []
        }
        #expect(store.state.photos.isEmpty)
    }

    @Test("펼친 사진이 없으면 리액션 탭은 아무 일도 하지 않는다")
    func ignoresReactionWithoutPhoto() async {
        let store = makeTestStore()

        await store.send(.view(.reactionTapped(.clap)))
    }
}
