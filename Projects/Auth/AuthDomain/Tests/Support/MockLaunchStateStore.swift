import AuthDomain
import Foundation
import os

final class MockLaunchStateStore: LaunchStateStore {

    private let launched: OSAllocatedUnfairLock<Bool>

    init(hasLaunchedBefore: Bool) {
        launched = OSAllocatedUnfairLock(initialState: hasLaunchedBefore)
    }

    var hasLaunchedBefore: Bool {
        launched.withLock { $0 }
    }

    func markLaunched() {
        launched.withLock { $0 = true }
    }
}
