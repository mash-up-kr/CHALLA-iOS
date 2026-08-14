import Foundation

/// 데모앱을 어느 화면의 어느 상태로 시작할지 나타낸다.
///
/// 실행 인자로 받는다 — 시뮬레이터를 탭으로 조작할 수 없어, 버튼을 눌러야 열리는 드로어는
/// 인자로 열어 두지 않으면 시안 대조 검증에서 확인할 수 없다
/// (규약은 CLAUDE.md, 쓰는 곳은 `zeplin-ui-verification` 스킬).
///
///     xcrun simctl launch booted <bundle-id> --screen list --state error
///     xcrun simctl launch booted <bundle-id> --screen create --state filled
enum DemoScreen: Hashable {

    /// 방 목록.
    case list(ListState)
    /// 상단 + 메뉴가 열린 목록.
    case menu
    /// 방 만들기 드로어가 열린 목록.
    case create(DrawerState)
    /// 초대 코드 입장 드로어가 열린 목록.
    case join(DrawerState)

    /// 목록 화면의 상태. 앞의 셋은 어떤 방이 있는지, 뒤의 셋은 조회가 어떻게 됐는지다.
    enum ListState: String, CaseIterable {
        /// 촬영 중 · 촬영 완료 두 섹션.
        case `default`
        /// 촬영 중 방만.
        case shooting
        /// 촬영 완료 방만.
        case printed
        /// 방이 하나도 없는 빈 상태.
        case empty
        /// 첫 조회 중.
        case loading
        /// 조회 실패 얼럿.
        case error
    }

    /// 드로어 화면의 상태. 시안이 버튼 잠김·활성 두 컷이라 입력값 유무로 나뉜다.
    enum DrawerState: String, CaseIterable {
        /// 입력이 비어 있어 버튼이 잠긴 상태.
        case `default`
        /// 입력이 채워져 버튼이 활성인 상태.
        case filled
    }
}

// MARK: - 실행 인자 파싱

extension DemoScreen {

    /// `--screen`이 없으면 nil — Xcode에서 그냥 Run 한 경우다.
    static func parse(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> DemoScreen? {
        guard let screen = value(of: "--screen", in: arguments) else { return nil }
        let stateValue = value(of: "--state", in: arguments)

        switch screen {
        case "list": return .list(state(stateValue, default: .default))
        case "menu": return .menu
        case "create": return .create(state(stateValue, default: .default))
        case "join": return .join(state(stateValue, default: .default))
        default:
            assertionFailure("--screen 값을 알 수 없음: \(screen)")
            return .list(.default)
        }
    }

    /// `--flag 값` 형태에서 값을 꺼낸다.
    private static func value(of flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
    }

    /// `--state` 문자열을 화면별 상태로 바꾼다. 오타를 조용히 기본값으로 넘기면
    /// 검증할 때 왜 엉뚱한 화면이 뜨는지 알 수 없어 assert로 멈춘다 (데모앱은 디버그로만 돈다).
    private static func state<State: RawRepresentable>(
        _ raw: String?,
        default fallback: State
    ) -> State where State.RawValue == String {
        guard let raw else { return fallback }
        guard let state = State(rawValue: raw) else {
            assertionFailure("--state 값을 알 수 없음: \(raw)")
            return fallback
        }
        return state
    }
}
