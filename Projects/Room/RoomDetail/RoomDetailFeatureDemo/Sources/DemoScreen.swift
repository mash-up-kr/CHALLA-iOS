import Foundation

/// 데모앱을 어느 화면의 어느 상태로 시작할지 나타낸다.
///
/// 실행 인자로 받는다 — 시뮬레이터를 탭으로 조작할 수 없어, 탭해야 열리는 초대 코드 팝오버·
/// 이름 수정 드로어는 인자로 열어 두지 않으면 시안 대조 검증에서 확인할 수 없다
/// (규약은 CLAUDE.md, 쓰는 곳은 `zeplin-ui-verification` 스킬).
///
///     xcrun simctl launch booted <bundle-id> --screen detail --state printWaiting
///     xcrun simctl launch booted <bundle-id> --screen settings --state rename
enum DemoScreen: Hashable {

    /// 방 상세.
    case detail(DetailState)
    /// 방 설정. 실제 앱에서는 상세 → 설정 전환을 App이 조립하지만 데모는 바로 띄운다.
    case settings(SettingsState)

    /// 앞의 넷은 방이 어느 단계인지, 뒤의 셋은 겹쳐 뜨는 화면과 조회 실패다.
    enum DetailState: String, CaseIterable {
        /// 촬영 중 · 아직 아무도 찍지 않아 슬롯이 전부 비어 있다.
        case shooting
        /// 촬영 중 · 일부만 찍혀 사진(블러)과 빈 슬롯이 섞인다.
        case shootingPartial
        /// 인화 대기 · 전부 블러 + 카운트다운.
        case printWaiting
        /// 인화 완료 · 전부 선명, 하단 버튼 없음.
        case printed
        /// 초대 코드 팝오버가 열린 촬영 중 화면.
        case invite
        /// 첫 진입 안내 — 팝오버가 저절로 열리고 아래에 툴팁이 붙는다.
        case inviteGuide
        /// 상세 조회 실패 — 얼럿이 뜨고, 다시 시도해도 실패하면 다시 뜬다.
        case error
    }

    /// 방 설정 화면의 상태.
    enum SettingsState: String, CaseIterable {
        /// 설정 화면만.
        case `default`
        /// 이름 수정 드로어가 열린 화면.
        case rename
    }
}

// MARK: - 실행 인자 파싱

extension DemoScreen {

    /// `--screen`이 없으면 nil — Xcode에서 그냥 Run 한 경우다.
    static func parse(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> DemoScreen? {
        guard let screen = value(of: "--screen", in: arguments) else { return nil }
        let stateValue = value(of: "--state", in: arguments)

        switch screen {
        case "detail": return .detail(state(stateValue, default: .shooting))
        case "settings": return .settings(state(stateValue, default: .default))
        default:
            assertionFailure("--screen 값을 알 수 없음: \(screen)")
            return .detail(.shooting)
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
