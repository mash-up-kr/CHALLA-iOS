@testable import RoomData
import Foundation
import os

/// 테스트가 실제 `UserDefaults`를 건드리지 않도록 메모리에만 담아두는 저장소.
final class InMemoryPrintNoticeStorage: PrintNoticeStorage {

    private let values = OSAllocatedUnfairLock<[String: Bool]>(initialState: [:])

    func bool(forKey key: String) -> Bool {
        values.withLock { $0[key] ?? false }
    }

    func setBool(_ value: Bool, forKey key: String) {
        values.withLock { $0[key] = value }
    }
}
