@testable import SettingFeature
import ComposableArchitecture
import SettingDomain
import Testing

/// `@MainActor` 밖에 둔다 — `withDependencies`에 넘기는 `@Sendable` 클로저가
/// 액터 경계를 넘어 이 값을 읽기 때문이다.
private enum Fixture {
    static let profile = SettingProfile(
        nickname: "나는야멋쟁이토마토",
        email: "hap****@naver.com",
        avatarURL: nil
    )
    static let theme = AppTheme.blueberry
}

@MainActor
struct SettingFeatureTests {

    private static var profile: SettingProfile {
        Fixture.profile
    }

    /// 프로필·테마를 둘 다 정상으로 채우는 기본 배선.
    private static func loadedStore() -> TestStoreOf<SettingFeature> {
        TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.loadProfileUseCase = LoadProfileUseCase(run: { Fixture.profile })
            $0.loadThemeUseCase = LoadThemeUseCase(run: { Fixture.theme })
        }
    }

    // MARK: - 불러오기

    @Test("화면에 들어오면 프로필과 테마를 각각 불러와 상태에 담는다")
    func loadsOnAppear() async {
        let store = Self.loadedStore()

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.themeLoaded) {
            $0.theme = .blueberry
        }
        await store.receive(\.profileResponse.success) {
            $0.isLoading = false
            $0.profile = Self.profile
        }
    }

    @Test("테마 행에 표시할 값은 불러온 테마의 이름이다")
    func themeDisplayName() async {
        let store = Self.loadedStore()

        // 불러오기 전에는 nil이어야 한다 — 빈 문자열을 넘기면 행이 "값 있음"으로 보고
        // 빈 Text와 간격을 그린다.
        #expect(store.state.themeDisplayName == nil)

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.themeLoaded) { $0.theme = .blueberry }
        await store.receive(\.profileResponse.success) {
            $0.isLoading = false
            $0.profile = Self.profile
        }

        #expect(store.state.themeDisplayName == "블루베리")
    }

    @Test("이미 불러왔으면 다시 불러오지 않는다 — 하위 화면에서 돌아올 때 깜빡이지 않게")
    func doesNotReloadWhenAlreadyLoaded() async {
        var state = SettingFeature.State()
        state.profile = Self.profile
        state.theme = .blueberry

        let store = TestStore(initialState: state) {
            SettingFeature()
        } withDependencies: {
            $0.loadProfileUseCase = LoadProfileUseCase(run: {
                Issue.record("이미 불러온 상태에서는 UseCase를 부르면 안 된다")
                return Fixture.profile
            })
            $0.loadThemeUseCase = LoadThemeUseCase(run: {
                Issue.record("이미 불러온 상태에서는 UseCase를 부르면 안 된다")
                return Fixture.theme
            })
        }

        await store.send(.view(.onAppear)) // 상태 변화도 이펙트도 없다
    }

    // MARK: - 프로필 실패

    @Test("프로필을 불러오지 못하면 얼럿을 띄운다")
    func showsAlertOnProfileFailure() async {
        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.loadProfileUseCase = LoadProfileUseCase(run: { throw SettingError.network })
            $0.loadThemeUseCase = LoadThemeUseCase(run: { Fixture.theme })
        }

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.themeLoaded) { $0.theme = .blueberry }
        await store.receive(\.profileResponse.failure) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState("프로필을 불러오지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(SettingError.network.userMessage)
            }
        }
    }

    @Test("프로필이 실패해도 테마는 남는다 — 로컬 값이 원격 실패에 끌려가지 않는다")
    func keepsThemeWhenProfileFails() async {
        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.loadProfileUseCase = LoadProfileUseCase(run: { throw SettingError.network })
            $0.loadThemeUseCase = LoadThemeUseCase(run: { Fixture.theme })
        }

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.themeLoaded) { $0.theme = .blueberry }
        await store.receive(\.profileResponse.failure) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState("프로필을 불러오지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(SettingError.network.userMessage)
            }
        }

        // 화면 표시값도, 하위 화면에 넘길 시드도 저장된 테마여야 한다.
        #expect(store.state.themeDisplayName == "블루베리")

        // 알림 화면 토글 색이 기본 테마로 떨어지던 회귀 지점이다.
        await store.send(.view(.notificationRowTapped)) {
            $0.path.append(.notification(NotificationSettingFeature.State(theme: .blueberry)))
        }
    }

    @Test("SettingError가 아닌 오류도 얼럿까지 도달한다 — 화면이 조용히 비어 있으면 안 된다")
    func normalizesUnknownError() async {
        struct Unexpected: Error {}

        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.loadProfileUseCase = LoadProfileUseCase(run: { throw Unexpected() })
            $0.loadThemeUseCase = LoadThemeUseCase(run: { Fixture.theme })
        }

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.themeLoaded) { $0.theme = .blueberry }
        await store.receive(\.profileResponse.failure) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState("프로필을 불러오지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(SettingError.unknown.userMessage)
            }
        }
    }

    // MARK: - 네비게이션 위임

    @Test(
        "설정 밖으로 나가야 하는 행은 delegate를 낸다 — 화면 전환 자체는 App의 몫이다",
        arguments: [
            (SettingFeature.Action.ViewAction.editProfileButtonTapped, SettingFeature.Action.Delegate.editProfileRequested),
            (.backButtonTapped, .backRequested)
        ]
    )
    func rowTapSendsDelegate(
        action: SettingFeature.Action.ViewAction,
        expected: SettingFeature.Action.Delegate
    ) async {
        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        }

        await store.send(.view(action))
        await store.receive(\.delegate, expected)
    }
}
