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

// MARK: - Mock State

extension DemoScenario {

    private static let filters = IdentifiedArray(
        uniqueElements: (1 ... 8).map { CameraFilter(id: "\($0)", name: "필터\($0)") }
    )

    private static let rooms = IdentifiedArray(uniqueElements: [
        CameraRoom(id: "1", name: "방이름방이름방이름1", remainingCards: 6, totalCards: 24),
        CameraRoom(id: "2", name: "방이름방이름방이름2", remainingCards: 6, totalCards: 24),
        CameraRoom(id: "3", name: "방이름방이름방이름3", remainingCards: 3, totalCards: 48),
        CameraRoom(id: "4", name: "방이름방이름방이름4", remainingCards: 3, totalCards: 48),
        // 말줄임 확인용 — 시안 SelectRoom 3행이 긴 이름 케이스다
        CameraRoom(id: "5", name: "방이름방이름방이름5방이름방이름방이름5", remainingCards: 3, totalCards: 48)
    ])

    private static let soldOutRooms = IdentifiedArray(uniqueElements: [
        CameraRoom(id: "3", name: "방이름방이름방이름3", remainingCards: 0, totalCards: 48)
    ])

    var featureState: CameraFeature.State {
        switch (screen, state) {
        case (.camera, .default):
            CameraFeature.State(
                rooms: Self.rooms,
                selectedRoomID: "3",
                filters: Self.filters,
                flashMode: .off
            )

        case (.camera, .error):
            CameraFeature.State(
                rooms: Self.soldOutRooms,
                filters: Self.filters,
                captureAvailability: .noCardsLeft,
                toastMessage: CameraCaptureAvailability.noCardsLeft.demoToastMessage
            )
        }
    }
}

private extension CameraCaptureAvailability {

    /// 토스트 초기 노출 시나리오용 — 셔터를 누르지 않고도 시안 상태를 그대로 띄운다.
    var demoToastMessage: String? {
        guard case let .unavailable(_, toastMessage) = self else { return nil }
        return toastMessage
    }
}
