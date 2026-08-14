import Foundation

public enum CameraPosition: Equatable, Sendable {
    case back
    case front

    mutating func toggle() {
        self = self == .back ? .front : .back
    }
}
