import ComposableArchitecture
import Foundation
import PhotoLibrary
import ProfileSetupFeature
import Testing
import UserDomain

/// `@MainActor` 밖에 둔다 — `withDependencies`에 넘기는 `@Sendable` 클로저가 액터 경계를 넘어 읽는다.
private enum Fixture {

    static let existingURL = URL(string: "https://cdn.example.com/existing.jpg")!

    static let savedProfile = UserProfile(id: 1, nickname: "찰나", imageURL: existingURL)

    static func editState(
        nickname: String = "찰나",
        remoteImageURL: URL? = existingURL
    ) -> ProfileSetupFeature.State {
        .init(mode: .edit, nickname: nickname, remoteImageURL: remoteImageURL)
    }
}

@MainActor
@Suite("ProfileSetupFeature — 편집 모드")
struct ProfileSetupEditTests: ProfileSetupTestSupport {

    // MARK: - 진입 상태

    @Test("편집 모드는 기존 값으로 시작한다")
    func seedsExistingValues() {
        let state = Fixture.editState()

        #expect(state.nickname == "찰나")
        #expect(state.avatarImageURL == Fixture.existingURL)
        #expect(state.isCTAEnabled) // 기존 닉네임이 유효하므로 바로 저장 가능
    }

    @Test("편집 모드에만 뒤로가기 버튼이 있다")
    func showsBackButtonOnlyInEditMode() {
        #expect(Fixture.editState().showsBackButton)
        #expect(ProfileSetupFeature.State(nickname: "찰나").showsBackButton == false)
    }

    @Test("서버 사진이 있으면 삭제 버튼을 낸다 — 최초 설정과 달리 지울 대상이 있다")
    func allowsRemovingRemotePhoto() {
        #expect(Fixture.editState().canRemovePhoto)
        #expect(Fixture.editState(remoteImageURL: nil).canRemovePhoto == false)
    }

    // MARK: - 사진 처리 방식 (기존 사진이 지워지지 않아야 한다)

    @Test("사진을 건드리지 않으면 .unchanged로 원본 URL을 들고 간다")
    func keepsRemoteImageWhenUntouched() {
        #expect(Fixture.editState().imageChange == .unchanged(Fixture.existingURL))
    }

    @Test("새 사진을 고르면 .replaced로 바뀐다")
    func replacesImageWhenPicked() {
        var state = Fixture.editState()
        state.imageData = Data("new".utf8)

        #expect(state.imageChange == .replaced(Data("new".utf8)))
    }

    @Test("사진을 지우면 .removed가 된다")
    func removesImageWhenDeleted() async {
        let store = makeStore(initialState: Fixture.editState(), clock: TestClock())

        await store.send(.view(.profileImageButtonTapped)) {
            $0.isPhotoMenuPresented = true
        }
        await store.send(.view(.photoRemoveTapped)) {
            $0.isPhotoMenuPresented = false
            $0.isPhotoRemoved = true
        }

        #expect(store.state.imageChange == .removed)
        #expect(store.state.avatarImageURL == nil) // 아바타도 실루엣으로 돌아간다
    }

    @Test("지웠다가 새로 고르면 삭제 의사가 무효가 된다")
    func pickingAfterRemovalWins() async {
        let store = makeStore(initialState: Fixture.editState(), clock: TestClock())
        let picked = Data("new".utf8)

        await store.send(.view(.profileImageButtonTapped)) { $0.isPhotoMenuPresented = true }
        await store.send(.view(.photoRemoveTapped)) {
            $0.isPhotoMenuPresented = false
            $0.isPhotoRemoved = true
        }
        await store.send(.photoLoadResponse(picked)) {
            $0.imageData = picked
            $0.isPhotoRemoved = false
        }

        #expect(store.state.imageChange == .replaced(picked))
    }

    @Test("닉네임만 바꿔 저장하면 서버로 원본 사진 URL이 그대로 간다")
    func savingNicknameOnlyKeepsPhoto() async {
        let receivedDrafts = LockIsolated<[ProfileDraft]>([])
        let store = makeStore(
            initialState: Fixture.editState(),
            clock: TestClock(),
            setupProfileUseCase: SetupProfileUseCase(run: { draft in
                receivedDrafts.withValue { $0.append(draft) }
                return Fixture.savedProfile
            })
        )

        await store.send(\.binding.nickname, "새닉네임") {
            $0.nickname = "새닉네임"
        }
        await store.send(.view(.startButtonTapped)) {
            $0.phase = .submitting
            $0.isNicknameFocused = false
        }
        await store.receive(\.submitResponse.success, Fixture.savedProfile) {
            $0.savedProfile = Fixture.savedProfile
            $0.nickname = "찰나" // 서버 응답 반영
        }
        await store.receive(\.delegate.editCompleted, Fixture.savedProfile)

        #expect(
            receivedDrafts.value == [
                ProfileDraft(nickname: "새닉네임", image: .unchanged(Fixture.existingURL))
            ]
        )
    }

    // MARK: - 완료·취소

    @Test("편집 저장은 환영 연출을 건너뛰고 곧바로 editCompleted를 올린다")
    func skipsWelcomeOnEdit() async {
        let store = makeStore(
            initialState: Fixture.editState(),
            clock: TestClock(),
            setupProfileUseCase: SetupProfileUseCase(run: { _ in Fixture.savedProfile })
        )

        await store.send(.view(.startButtonTapped)) {
            $0.phase = .submitting
            $0.isNicknameFocused = false
        }
        await store.receive(\.submitResponse.success, Fixture.savedProfile) {
            $0.savedProfile = Fixture.savedProfile
        }
        await store.receive(\.delegate.editCompleted, Fixture.savedProfile)

        // 환영 화면으로 가지 않으므로 대기 시간도 없다.
        #expect(store.state.phase == .submitting)
        #expect(store.state.showsWelcome == false)
    }

    @Test("뒤로가기를 누르면 변경을 버리고 cancelled를 올린다")
    func cancelsOnBack() async {
        let store = makeStore(initialState: Fixture.editState(), clock: TestClock())

        await store.send(\.binding.nickname, "안 저장될 닉네임") {
            $0.nickname = "안 저장될 닉네임"
        }
        await store.send(.view(.backButtonTapped))
        await store.receive(\.delegate.cancelled)
    }

    @Test("제출 중에는 뒤로가기가 막힌다 — 나가면 성공도 실패도 오지 않는다")
    func blocksBackWhileSubmitting() async {
        var state = Fixture.editState()
        state.phase = .submitting
        let store = makeStore(initialState: state, clock: TestClock())

        await store.send(.view(.backButtonTapped)) // 아무 액션도 뒤따르지 않는다
        #expect(store.state.phase == .submitting)
    }
}
