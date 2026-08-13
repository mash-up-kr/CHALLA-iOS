import Foundation

/// 남은 장수를 어떤 색으로 보여줄지 결정하는 단계.
public enum CameraCardsLevel: Equatable, Sendable {
    case normal
    case low
    case unavailable

    /// 5장 이하부터 경고로 본다.
    static let lowThreshold = 5

    init(remaining: Int) {
        switch remaining {
        case ...0: self = .unavailable
        case ...Self.lowThreshold: self = .low
        default: self = .normal
        }
    }
}
