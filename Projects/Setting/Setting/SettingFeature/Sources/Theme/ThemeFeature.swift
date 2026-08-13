import ComposableArchitecture
import SettingDomain

/// 테마 선택 화면의 TCA Feature.
///
/// 여섯 개 중 하나를 고르면 체크를 옮기고 `delegate`로 부모(설정 화면)에 알린다.
/// **읽기도 저장도 부모가 한다** — 부모가 테마를 따로 들고 있어 시드가 항상 맞고,
/// 부모 이펙트는 이 화면이 pop돼도 취소되지 않는다.
///
/// **고른 뒤 화면을 닫지 않는다** — 체크만 옮기고 그대로 머문다.
/// 저장이 즉시 끝나 결과가 화면에 남고, 잘못 눌렀을 때 그 자리에서 다시 고를 수 있다.
/// (iOS 설정 앱의 단일 선택 목록도 같은 동작이다)
@Reducer
public struct ThemeFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {

        /// 현재 선택된 테마. 부모가 시드하고, 이 화면에서 고른 값은 delegate로 부모가 받는다.
        public var selectedTheme: AppTheme

        public init(selectedTheme: AppTheme) {
            self.selectedTheme = selectedTheme
        }
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        /// UI에서만 트리거되는 액션 (`@ViewAction` 뷰가 `send(...)`로 호출).
        public enum ViewAction: Sendable {
            case themeTapped(AppTheme)
            case backButtonTapped
        }

        case view(ViewAction)

        /// 부모에게만 알린다.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            /// 사용자가 다른 테마를 골랐다. 부모가 표시값을 갱신하고 저장한다.
            case themeChanged(AppTheme)
        }

        case delegate(Delegate)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.dismiss) var dismiss

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(.themeTapped(theme)):
                // 같은 테마를 다시 눌렀다 — 알릴 변화가 없다.
                guard theme != state.selectedTheme else { return .none }
                state.selectedTheme = theme
                return .send(.delegate(.themeChanged(theme)))

            case .view(.backButtonTapped):
                // 스택에서 스스로 빠진다 — 부모는 pop을 모른다.
                return .run { [dismiss] _ in await dismiss() }

            case .delegate:
                return .none
            }
        }
    }
}
