import ComposableArchitecture
import SettingDomain

/// 테마 선택 화면의 TCA Feature.
///
/// 여섯 개 중 하나를 고르면 `@Shared(.appTheme)`에 바로 쓴다. 설정 화면과 앱 루트가 같은 값을
/// 읽으므로 여기서 쓰면 함께 갱신된다. 그래서 부모에게 알릴 `delegate`가 없다.
///
/// **고른 뒤 화면을 닫지 않는다** — 체크만 옮기고 그대로 머문다.
/// 저장이 즉시 끝나 결과가 화면에 남고, 잘못 눌렀을 때 그 자리에서 다시 고를 수 있다.
/// (iOS 설정 앱의 단일 선택 목록도 같은 동작이다)
@Reducer
public struct ThemeFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {

        /// 현재 선택된 테마. 저장소를 직접 읽으므로 부모가 시드하지 않는다.
        @Shared(.appTheme) public var selectedTheme: AppTheme

        public init() {}
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        /// UI에서만 트리거되는 액션 (`@ViewAction` 뷰가 `send(...)`로 호출).
        public enum ViewAction: Sendable {
            case themeTapped(AppTheme)
            case backButtonTapped
        }

        case view(ViewAction)
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
                // 같은 테마를 다시 눌렀다 — 저장소에 같은 값을 다시 쓰지 않는다.
                guard theme != state.selectedTheme else { return .none }
                state.$selectedTheme.withLock { $0 = theme }
                return .none

            case .view(.backButtonTapped):
                // 스택에서 스스로 빠진다 — 부모는 pop을 모른다.
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}
