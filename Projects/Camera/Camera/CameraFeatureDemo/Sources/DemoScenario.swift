import CameraFeature
import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain

/// 데모앱이 실행 인자로 받는 진입 지점.
struct DemoScenario: Equatable {

    enum Screen: String {
        case camera
    }

    enum State: String {
        case `default`
        case error
        /// 최초 진입 — 뜸을 들인 뒤 안내 1단계가 뜨고, "다음"을 누르면 2단계로 이어진다.
        case coach
    }

    let screen: Screen
    let state: State

    static let all: [DemoScenario] = [
        DemoScenario(screen: .camera, state: .default),
        DemoScenario(screen: .camera, state: .coach),
        DemoScenario(screen: .camera, state: .error)
    ]

    var label: String {
        switch (screen, state) {
        case (.camera, .default): "카메라"
        case (.camera, .coach): "카메라 최초 진입 — 안내 (camera_snackBar_1 → 2)"
        case (.camera, .error): "카메라 — 촬영 불가 + 토스트"
        }
    }

    /// 최초 진입 안내를 띄울 시나리오인지. 안내를 보려고 들어온 시나리오에서만 켠다 —
    /// 나머지는 이미 본 것으로 두고 안내 없는 평상시 화면을 보여준다.
    var showsCoachMark: Bool {
        state == .coach
    }

    /// 실행 인자에서 시나리오를 읽는다. `--screen`이 없으면 nil (목록 화면).
    static func fromLaunchArguments(_ arguments: [String] = CommandLine.arguments) -> DemoScenario? {
        guard let rawScreen = value(of: "--screen", in: arguments),
              let screen = Screen(rawValue: normalized(rawScreen))
        else { return nil }

        let rawState = value(of: "--state", in: arguments).map(normalized) ?? State.default.rawValue
        return DemoScenario(screen: screen, state: State(rawValue: rawState) ?? .default)
    }

    private static func value(of flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    /// kebab 표기를 enum의 camelCase로 맞춘다.
    private static func normalized(_ raw: String) -> String {
        let parts = raw.split(separator: "-").map(String.init)
        guard let first = parts.first else { return raw }
        return ([first] + parts.dropFirst().map(\.capitalized)).joined()
    }
}

// MARK: - 초기 State

/// 방·필터는 진입 화면(`CameraEntryView`)이 미리 받아 넘긴다 —
/// 여기서는 데이터로 만들 수 없는 초기 연출(플래시·토스트)만 얹는다.
extension DemoScenario {

    func featureState(rooms: [ShootableRoom], filters: [CameraFilter]) -> CameraFeature.State {
        let rooms = IdentifiedArray(uniqueElements: rooms)
        let filters = IdentifiedArray(uniqueElements: filters)

        switch (screen, state) {
        // 안내는 심지 않고 리듀서가 진입 시 스스로 띄우게 둔다 — 등장 연출과 단계 전환을 그대로 확인한다.
        case (.camera, .default), (.camera, .coach):
            return CameraFeature.State(rooms: rooms, filters: filters, flashMode: .off)

        case (.camera, .error):
            // 토스트 초기 노출 — 셔터를 누르지 않고도 시안 상태를 그대로 띄운다.
            // 촬영 불가 자체는 소진된 방(장수 0)이 넘어오면 리듀서가 알아서 판단한다.
            return CameraFeature.State(
                rooms: rooms,
                filters: filters,
                toastMessage: CameraCaptureAvailability.noCardsLeft.demoToastMessage
            )
        }
    }
}

private extension CameraCaptureAvailability {

    var demoToastMessage: String? {
        guard case let .unavailable(_, toastMessage) = self else { return nil }
        return toastMessage
    }
}
