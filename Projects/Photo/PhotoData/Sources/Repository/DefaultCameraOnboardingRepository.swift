import Foundation
import PhotoDomain

/// `CameraOnboardingRepository`의 기본 구현 — 안내 노출 여부를 기기에 저장한다.
public struct DefaultCameraOnboardingRepository: CameraOnboardingRepository {

    private enum Key {
        static let coachMarkSeen = "challa.camera.coachMark.seen"
    }

    private let storage: any CameraOnboardingStorage

    public init(storage: any CameraOnboardingStorage = UserDefaultsCameraOnboardingStorage()) {
        self.storage = storage
    }

    public func hasSeenCoachMark() async -> Bool {
        storage.bool(forKey: Key.coachMarkSeen)
    }

    public func markCoachMarkSeen() async {
        storage.setBool(true, forKey: Key.coachMarkSeen)
    }
}
