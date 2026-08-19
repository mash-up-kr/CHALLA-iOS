import Foundation
import PhotoDomain

/// 데모·테스트용 가짜 온보딩 기록소. 앱을 끄면 사라져 매번 안내부터 다시 볼 수 있다.
public actor InMemoryCameraOnboardingRepository: CameraOnboardingRepository {

    private var hasSeen: Bool

    public init(hasSeen: Bool = false) {
        self.hasSeen = hasSeen
    }

    public func hasSeenCoachMark() async -> Bool {
        hasSeen
    }

    public func markCoachMarkSeen() async {
        hasSeen = true
    }
}
