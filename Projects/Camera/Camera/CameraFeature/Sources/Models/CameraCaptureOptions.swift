import CHALLADesignSystem
import Foundation

public enum CameraFlashMode: Equatable, Sendable {
    case on
    case off

    mutating func toggle() {
        self = self == .on ? .off : .on
    }

    var icon: CHALLAIcon {
        switch self {
        case .on: .lightningOn
        case .off: .lightningOff
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .on: "플래시 켜짐"
        case .off: "플래시 꺼짐"
        }
    }
}

public enum CameraPosition: Equatable, Sendable {
    case back
    case front

    mutating func toggle() {
        self = self == .back ? .front : .back
    }
}
