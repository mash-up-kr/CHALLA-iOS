@testable import RoomDetailFeature
import ComposableArchitecture
import RoomDomain
import Testing

@MainActor
@Suite("RenameRoomFeature")
struct RenameRoomFeatureTests {

    private nonisolated static let roomID = Room.previewShooting.id
    private nonisolated static let originalTitle = "제주 우정 여행"

    private static func makeStore(
        update: UpdateRoomTitleUseCase = .testValue,
        isDismissed: LockIsolated<Bool>? = nil
    ) -> TestStoreOf<RenameRoomFeature> {
        TestStore(initialState: RenameRoomFeature.State(roomID: roomID, title: originalTitle)) {
            RenameRoomFeature()
        } withDependencies: {
            $0.updateRoomTitleUseCase = update
            if let isDismissed {
                $0.dismiss = DismissEffect { isDismissed.setValue(true) }
            }
        }
    }

    // MARK: - 초기 상태 · 버튼 활성 조건

    @Test("현재 이름이 미리 채워지고, 그대로라 변경 버튼이 잠겨 있다")
    func startsWithOriginalTitlePrefilled() {
        let state = RenameRoomFeature.State(roomID: Self.roomID, title: Self.originalTitle)

        #expect(state.name == Self.originalTitle)
        #expect(!state.canSubmit)
    }

    /// canSubmit은 순수 계산이라 스토어 없이 조건별로 본다.
    @Test("제출 중이면 규칙에 맞는 새 이름이라도 버튼이 잠긴다")
    func lockedWhileSubmitting() {
        var state = RenameRoomFeature.State(roomID: Self.roomID, title: Self.originalTitle)
        state.name = "강릉 여행"
        state.isSubmitting = true

        #expect(!state.canSubmit)
    }

    @Test("공백만 친 이름은 버튼이 잠긴다")
    func lockedForBlankName() {
        var state = RenameRoomFeature.State(roomID: Self.roomID, title: Self.originalTitle)
        state.name = "   "

        #expect(!state.canSubmit)
    }

    @Test("원래 이름과 같으면 버튼이 잠기고, 달라지면 열린다")
    func lockedForUnchangedName() {
        var state = RenameRoomFeature.State(roomID: Self.roomID, title: Self.originalTitle)
        state.name = Self.originalTitle
        #expect(!state.canSubmit)

        state.name = "강릉 여행"
        #expect(state.canSubmit)
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

    // MARK: - 제출

    @Test("제출 성공: 요청 중 표시가 켜졌다 꺼지고, UseCase가 정제한 이름이 delegate로 나간다")
    func submitSuccessDelegatesRefinedName() async {
        let requestedNames = LockIsolated<[String]>([])
        // 입력값과 다른 값을 돌려주는 목 — delegate가 입력값이 아니라 UseCase 반환값을 쓰는지 가른다.
        let store = Self.makeStore(
            update: UpdateRoomTitleUseCase(run: { _, name in
                requestedNames.withValue { $0.append(name) }
                return "강릉 여행"
            })
        )

        await store.send(\.binding.name, " 강릉 여행 ") {
            $0.name = " 강릉 여행 "
        }
        await store.send(.view(.submitButtonTapped)) {
            $0.isSubmitting = true
        }
        await store.receive(\.renameResponse.success) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.renamed, "강릉 여행")

        // 정제는 UseCase 몫 — 리듀서는 입력값을 그대로 넘긴다.
        #expect(requestedNames.value == [" 강릉 여행 "])
    }

    @Test("제출 실패: 얼럿을 띄우고 입력값을 유지한다")
    func submitFailureShowsAlertKeepingInput() async {
        let store = Self.makeStore(
            update: UpdateRoomTitleUseCase(run: { _, _ in throw RoomError.network })
        )

        await store.send(\.binding.name, "강릉 여행") {
            $0.name = "강릉 여행"
        }
        await store.send(.view(.submitButtonTapped)) {
            $0.isSubmitting = true
        }
        await store.receive(\.renameResponse.failure) {
            $0.isSubmitting = false
            $0.alert = AlertState {
                TextState("방 이름을 바꾸지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(RoomError.network.userMessage)
            }
        }
        // 얼럿을 닫아도 입력값이 남아 있어 그대로 다시 시도할 수 있다.
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        #expect(store.state.name == "강릉 여행")
    }

    @Test("버튼이 잠긴 상태의 제출은 무시된다")
    func submitIgnoredWhenLocked() async {
        // 의존성을 주입하지 않는다 — 가드를 지나 요청이 실행되면 testValue가 테스트를 실패시킨다.
        let store = Self.makeStore()

        // 이름이 원래 그대로라 canSubmit이 false다.
        await store.send(.view(.submitButtonTapped))
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
