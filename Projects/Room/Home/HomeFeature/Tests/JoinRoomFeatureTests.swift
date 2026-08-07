import ComposableArchitecture
import RoomDomain
import Testing

@testable import HomeFeature

@MainActor
@Suite("JoinRoomFeature")
struct JoinRoomFeatureTests {

    private static func makeStore(
        initialState: JoinRoomFeature.State = JoinRoomFeature.State(),
        joinRoom: JoinRoomUseCase = .testValue,
        isDismissed: LockIsolated<Bool>? = nil
    ) -> TestStoreOf<JoinRoomFeature> {
        TestStore(initialState: initialState) {
            JoinRoomFeature()
        } withDependencies: {
            $0.joinRoomUseCase = joinRoom
            if let isDismissed {
                $0.dismiss = DismissEffect { isDismissed.setValue(true) }
            }
        }
    }

    // MARK: - 입력

    @Test("공백만 입력한 코드로는 입장 버튼이 잠긴다")
    func whitespaceCodeLocksSubmit() async {
        let store = Self.makeStore()

        await store.send(\.binding.code, "   ") {
            $0.code = "   "
        }
        #expect(!store.state.canSubmit)

        await store.send(\.binding.code, "1928121") {
            $0.code = "1928121"
        }
        #expect(store.state.canSubmit)
    }

    @Test("입력 중에는 공백을 지우지 않는다")
    func codeIsStoredAsTyped() async {
        // 타이핑 중 공백을 지우면 커서가 튀어 입력 시점에는 손대지 않는다.
        // 앞뒤 공백 제거는 제출 시점에 UseCase가 한다 (InviteCodeRuleTests가 규칙 자체를 검증).
        let store = Self.makeStore()

        await store.send(\.binding.code, " 1928121 ") {
            $0.code = " 1928121 "
        }
    }

    // MARK: - 입장

    @Test("입장 성공은 delegate로 방을 알린다")
    func joinSuccessDelegates() async {
        let joined = Room.previewShooting
        let receivedCodes = LockIsolated<[String]>([])
        let store = Self.makeStore(
            joinRoom: JoinRoomUseCase(run: { code in
                receivedCodes.withValue { $0.append(code) }
                return joined
            })
        )

        await store.send(\.binding.code, " 1928121 ") {
            $0.code = " 1928121 "
        }
        await store.send(.view(.joinButtonTapped)) {
            $0.isJoining = true
        }
        await store.receive(\.joinResponse.success) {
            $0.isJoining = false
        }
        await store.receive(\.delegate.joined, joined)
        // 다듬지 않은 입력이 그대로 UseCase로 간다 — 정규화는 UseCase 책임이다.
        #expect(receivedCodes.value == [" 1928121 "])
    }

    @Test("코드가 비어 있으면 입장 탭을 무시한다")
    func emptyCodeIgnoresJoinTap() async {
        // 의존성을 주입하지 않는다 — 가드를 뚫으면 testValue가 테스트를 실패시킨다.
        let store = Self.makeStore()

        await store.send(.view(.joinButtonTapped))
    }

    @Test("요청 중에는 입장을 다시 시작하지 않는다")
    func ignoresDuplicateJoinWhileInFlight() async {
        var state = JoinRoomFeature.State()
        state.code = "1928121"
        state.isJoining = true
        let store = Self.makeStore(initialState: state)

        await store.send(.view(.joinButtonTapped))
    }

    @Test("없는 코드는 얼럿을 띄우고 입력값을 유지한다")
    func roomNotFoundShowsAlertKeepingInput() async {
        let store = Self.makeStore(
            joinRoom: JoinRoomUseCase(run: { _ in throw RoomError.roomNotFound })
        )

        await store.send(\.binding.code, "0000000") {
            $0.code = "0000000"
        }
        await store.send(.view(.joinButtonTapped)) {
            $0.isJoining = true
        }
        await store.receive(\.joinResponse.failure) {
            $0.isJoining = false
            $0.alert = AlertState {
                TextState("방에 입장하지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(RoomError.roomNotFound.userMessage)
            }
        }
        // 얼럿을 닫아도 코드가 남아 있어 틀린 자리만 고쳐 다시 시도할 수 있다.
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        #expect(store.state.code == "0000000")
    }

    // MARK: - 닫기

    @Test("닫기 버튼은 dismiss를 부른다")
    func closeButtonDismisses() async {
        let isDismissed = LockIsolated(false)
        let store = Self.makeStore(isDismissed: isDismissed)

        await store.send(.view(.closeButtonTapped)).finish()
        #expect(isDismissed.value)
    }
}
