import ComposableArchitecture
import RoomDomain
import Testing

@testable import HomeFeature

@MainActor
@Suite("CreateRoomFeature")
struct CreateRoomFeatureTests {

    private static func makeStore(
        initialState: CreateRoomFeature.State = CreateRoomFeature.State(),
        createRoom: CreateRoomUseCase = .testValue,
        isDismissed: LockIsolated<Bool>? = nil
    ) -> TestStoreOf<CreateRoomFeature> {
        TestStore(initialState: initialState) {
            CreateRoomFeature()
        } withDependencies: {
            $0.createRoomUseCase = createRoom
            if let isDismissed {
                $0.dismiss = DismissEffect { isDismissed.setValue(true) }
            }
        }
    }

    // MARK: - 입력

    @Test("이름 입력은 20자로 잘려 저장된다")
    func nameIsSanitizedOnBinding() async {
        let store = Self.makeStore()
        let long = String(repeating: "가", count: 25)

        await store.send(\.binding.name, long) {
            $0.name = String(repeating: "가", count: 20)
        }
    }

    @Test("공백만 입력한 이름으로는 만들기 버튼이 잠긴다")
    func whitespaceNameLocksSubmit() async {
        let store = Self.makeStore()

        // 공백도 이름 값으로는 저장된다 — sanitize는 길이만 자른다.
        // 거부는 저장이 아니라 canSubmit(제출 판단)에서 일어난다.
        await store.send(\.binding.name, "   ") {
            $0.name = "   "
        }
        #expect(!store.state.canSubmit)

        await store.send(\.binding.name, " 제주 여행 ") {
            $0.name = " 제주 여행 "
        }
        #expect(store.state.canSubmit)
    }

    @Test("촬영 매수는 기본 24장이고 선택하면 바뀐다")
    func shotCountSelection() async {
        let store = Self.makeStore()
        #expect(store.state.shotCount == .twentyFour)

        await store.send(.view(.shotCountSelected(.seventyTwo))) {
            $0.shotCount = .seventyTwo
        }
    }

    // MARK: - 생성

    @Test("만들기 성공은 delegate로 방을 알린다")
    func createSuccessDelegates() async {
        let created = Room.previewShooting
        let store = Self.makeStore(createRoom: CreateRoomUseCase(run: { _ in created }))

        await store.send(\.binding.name, "제주 우정 여행") {
            $0.name = "제주 우정 여행"
        }
        await store.send(.view(.createButtonTapped)) {
            $0.isCreating = true
        }
        await store.receive(\.createResponse.success) {
            $0.isCreating = false
        }
        await store.receive(\.delegate.created, created)
    }

    @Test("이름이 비어 있으면 만들기 탭을 무시한다")
    func emptyNameIgnoresCreateTap() async {
        // 의존성을 주입하지 않는다 — 가드를 뚫으면 testValue가 테스트를 실패시킨다.
        let store = Self.makeStore()

        await store.send(.view(.createButtonTapped))
    }

    @Test("요청 중에는 만들기를 다시 시작하지 않는다")
    func ignoresDuplicateCreateWhileInFlight() async {
        var state = CreateRoomFeature.State()
        state.name = "제주"
        state.isCreating = true
        let store = Self.makeStore(initialState: state)

        await store.send(.view(.createButtonTapped))
    }

    @Test("만들기 실패는 얼럿을 띄우고 입력값을 유지한다")
    func createFailureShowsAlertKeepingInput() async {
        let store = Self.makeStore(
            createRoom: CreateRoomUseCase(run: { _ in throw RoomError.network })
        )

        await store.send(\.binding.name, "제주 우정 여행") {
            $0.name = "제주 우정 여행"
        }
        await store.send(.view(.createButtonTapped)) {
            $0.isCreating = true
        }
        await store.receive(\.createResponse.failure) {
            $0.isCreating = false
            $0.alert = AlertState {
                TextState("방을 만들지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(RoomError.network.userMessage)
            }
        }
        // 얼럿을 닫아도 이름·매수가 남아 있어 그대로 다시 시도할 수 있다.
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        #expect(store.state.name == "제주 우정 여행")
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
