import CameraFeature
import ComposableArchitecture
import Foundation

/// 데모앱이 실행 인자로 받는 진입 지점.
struct DemoScenario: Equatable {

    enum Screen: String {
        case camera
    }

    enum State: String {
        case `default`
        case error
    }

    let screen: Screen
    let state: State

    static let all: [DemoScenario] = [
        DemoScenario(screen: .camera, state: .default),
        DemoScenario(screen: .camera, state: .error)
    ]

    var label: String {
        switch (screen, state) {
        case (.camera, .default): "카메라"
        case (.camera, .error): "카메라 — 촬영 불가 + 토스트"
        }
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

/// 방·필터 데이터는 `CompositionRoot`가 시나리오별 저장소로 꽂고, 리듀서가 진입 시 스스로 불러온다 —
/// 여기서는 데이터로 만들 수 없는 초기 연출(플래시·토스트)만 구성한다.
extension DemoScenario {

    var featureState: CameraFeature.State {
        switch (screen, state) {
        case (.camera, .default):
            CameraFeature.State(flashMode: .off)

        case (.camera, .error):
            // 토스트 초기 노출 — 셔터를 누르지 않고도 시안 상태를 그대로 띄운다.
            // 촬영 불가 자체는 소진된 방이 로드되면 리듀서가 다시 계산한다.
            CameraFeature.State(
                captureAvailability: .noCardsLeft,
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
