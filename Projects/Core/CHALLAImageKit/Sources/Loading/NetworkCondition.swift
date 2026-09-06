import Foundation
import Network

/// 다운로드 동시성을 제한할 네트워크·전력 상태.
public protocol NetworkCondition: Sendable {

    /// 셀룰러·저데이터 모드·저전력 모드 중 하나라도 해당되면 true.
    var isConstrained: Bool { get }
}

/// 네트워크·전력 상태를 조회한다. 기본 인스턴스는 모니터를 공유한다.
public final class SystemNetworkCondition: NetworkCondition, @unchecked Sendable {

    public static let shared = SystemNetworkCondition()

    private let lock = NSLock()
    private var isExpensiveOrConstrained = false
    private let monitor = NWPathMonitor()

    public init() {
        // 시작 전 monitor.currentPath는 아직 아무것도 관측하지 않은 기본값이라 셀룰러에서도
        // "여유 있음"으로 나온다 — 읽어 둬도 도움이 안 돼서 첫 콜백을 기다린다.
        // 그 사이 시작된 배치는 동시 개수를 못 줄이지만, 저전력 모드는 isConstrained가 매번 직접 읽어 걸러진다.
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            lock.withLock { isExpensiveOrConstrained = path.isExpensive || path.isConstrained }
        }
        monitor.start(queue: DispatchQueue(label: "com.challa.imagekit.networkcondition"))
    }

    deinit {
        monitor.cancel()
    }

    public var isConstrained: Bool {
        let network = lock.withLock { isExpensiveOrConstrained }
        return network || ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}
