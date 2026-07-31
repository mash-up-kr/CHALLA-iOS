@testable import SettingFeature
import ComposableArchitecture
import SettingDomain
import Testing

/// `@MainActor` 밖에 둔다 — `withDependencies`에 넘기는 `@Sendable` 클로저가
/// 액터 경계를 넘어 이 값을 읽기 때문이다.
private enum Fixture {
    static let snapshot = SettingsSnapshot(
        profile: SettingProfile(
            nickname: "나는야멋쟁이토마토",
            email: "juy***@naver,com",
            avatarURL: nil
        ),
        theme: .blueberry
    )
}

@MainActor
struct SettingFeatureTests {

    private static var snapshot: SettingsSnapshot {
        Fixture.snapshot
    }

    // MARK: - 불러오기

    @Test("화면에 들어오면 설정을 불러와 상태에 담는다")
    func loadsOnAppear() async {
        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.loadSettingsUseCase = LoadSettingsUseCase(run: { Fixture.snapshot })
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.settingsResponse.success) {
            $0.isLoading = false
            $0.snapshot = Self.snapshot
        }
    }

    @Test("테마 행에 표시할 값은 불러온 테마의 이름이다")
    func themeDisplayName() async {
        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.loadSettingsUseCase = LoadSettingsUseCase(run: { Fixture.snapshot })
        }

        // 불러오기 전에는 nil이어야 한다 — 빈 문자열을 넘기면 행이 "값 있음"으로 보고
        // 빈 Text와 간격을 그린다.
        #expect(store.state.themeDisplayName == nil)

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.settingsResponse.success) {
            $0.isLoading = false
            $0.snapshot = Self.snapshot
        }

        #expect(store.state.themeDisplayName == "블루베리")
    }

    @Test("이미 불러왔으면 다시 불러오지 않는다 — 하위 화면에서 돌아올 때 깜빡이지 않게")
    func doesNotReloadWhenAlreadyLoaded() async {
        var state = SettingFeature.State()
        state.snapshot = Self.snapshot

        let store = TestStore(initialState: state) {
            SettingFeature()
        } withDependencies: {
            $0.loadSettingsUseCase = LoadSettingsUseCase(run: {
                Issue.record("이미 불러온 상태에서는 UseCase를 부르면 안 된다")
                return Fixture.snapshot
            })
        }

        await store.send(.view(.onAppear)) // 상태 변화도 이펙트도 없다
    }

    @Test("불러오기에 실패하면 얼럿을 띄운다")
    func showsAlertOnFailure() async {
        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.loadSettingsUseCase = LoadSettingsUseCase(run: { throw SettingError.network })
        }

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.settingsResponse.failure) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState("설정을 불러오지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(SettingError.network.userMessage)
            }
        }
    }

    @Test("SettingError가 아닌 오류도 얼럿까지 도달한다 — 화면이 조용히 비어 있으면 안 된다")
    func normalizesUnknownError() async {
        struct Unexpected: Error {}

        let store = TestStore(initialState: SettingFeature.State()) {
            SettingFeature()
        } withDependencies: {
            $0.loadSettingsUseCase = LoadSettingsUseCase(run: { throw Unexpected() })
        }

        await store.send(.view(.onAppear)) { $0.isLoading = true }
        await store.receive(\.settingsResponse.failure) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState("설정을 불러오지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(SettingError.unknown.userMessage)
            }
        }
    }

    // MARK: - 네비게이션 위임

    @Test(
        "각 행을 누르면 대응하는 delegate를 낸다 — 화면 전환 자체는 App의 몫이다",
        arguments: [
            (SettingFeature.Action.ViewAction.editProfileButtonTapped, SettingFeature.Action.Delegate.editProfileRequested),
            (.themeRowTapped, .themeSelectionRequested),
            (.notificationRowTapped, .notificationSettingRequested),
            (.accountRowTapped, .accountManagementRequested),
            (.supportRowTapped, .supportRequested),
            (.feedbackRowTapped, .feedbackRequested),
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
