import UIKit

/// 다운샘플된 `UIImage`를 메모리에 보관하는 LRU 캐시.
///
/// 각 이미지의 메모리 사용량(`cost`)을 합산하고,
/// `costLimit`을 넘으면 가장 오래 사용하지 않은 이미지부터 제거한다.
///
/// 이 타입 자체는 동시성 제어를 하지 않는다.
/// `ImageLoader` actor 내부에서만 사용되므로 모든 접근이 이미 직렬화되기 때문이다.
///
/// 메모리 조회는 Dictionary 접근처럼 매우 짧은 동기 작업이므로 별도 actor로 분리하지 않는다.
/// 반대로 파일 I/O처럼 오래 걸릴 수 있는 작업은 `DiskImageCache`에서 별도 actor로 처리한다.
final class MemoryImageCache {

    // MARK: - Entry

    /// 캐시에 저장되는 이미지 한 건.
    private struct Entry {
        /// 실제 이미지.
        let image: UIImage

        /// 디코딩된 이미지가 메모리에서 차지하는 크기(Byte).
        let cost: Int

        /// 마지막으로 사용된 순서.
        /// 값이 작을수록 더 오래 사용되지 않은 이미지다.
        var lastUsed: UInt64
    }

    // MARK: - Properties

    /// 캐시가 사용할 수 있는 최대 메모리 비용.
    private let costLimit: Int

    /// 이미지 키 → 캐시 항목.
    private var entries: [ImageCacheKey: Entry] = [:]

    /// 현재 캐시에 저장된 이미지들의 총 메모리 비용.
    private var totalCost = 0

    /// 이미지 사용 순서를 기록하기 위한 증가값.
    ///
    /// 실제 시간(Date)을 사용하는 대신 1, 2, 3... 순서만 기록하면
    /// 어떤 이미지가 더 최근에 사용됐는지만 정확하게 비교할 수 있다.
    private var useCounter: UInt64 = 0

    // MARK: - Init

    init(costLimit: Int) {
        self.costLimit = costLimit
    }

    // MARK: - Lookup

    /// 캐시에 이미지가 있으면 반환한다.
    ///
    /// 조회에 성공한 이미지는 "최근 사용"으로 갱신되어
    /// LRU 방출 우선순위가 뒤로 밀린다.
    func image(for key: ImageCacheKey) -> UIImage? {
        guard var entry = entries[key] else {
            return nil
        }

        useCounter += 1
        entry.lastUsed = useCounter
        entries[key] = entry

        return entry.image
    }

    // MARK: - Insert

    /// 이미지를 캐시에 저장한다.
    ///
    /// 저장 후 총 비용이 `costLimit`을 넘으면
    /// 가장 오래 사용하지 않은 이미지부터 제거한다.
    ///
    /// - Parameters:
    ///   - image: 저장할 다운샘플 이미지.
    ///   - key: 이미지를 구분하는 캐시 키.
    ///   - cost: 디코딩된 이미지의 메모리 사용량(Byte).
    func insert(
        _ image: UIImage,
        for key: ImageCacheKey,
        cost: Int
    ) {
        // 같은 키가 이미 있다면 기존 항목의 비용을 먼저 제거한다.
        if let previous = entries[key] {
            totalCost -= previous.cost
        }

        useCounter += 1

        entries[key] = Entry(
            image: image,
            cost: cost,
            lastUsed: useCounter
        )

        totalCost += cost

        evictIfNeeded()
    }

    // MARK: - Remove

    /// 캐시에 저장된 모든 이미지를 제거한다.
    ///
    /// 로그아웃이나 메모리 경고 등에서 상위 계층이 호출한다.
    func removeAll() {
        entries.removeAll()
        totalCost = 0
    }

    /// 현재 캐시가 사용 중인 총 메모리 비용(Byte).
    var currentCost: Int {
        totalCost
    }

    // MARK: - Eviction

    /// 총 비용이 상한 이하가 될 때까지 LRU 순서로 이미지를 제거한다.
    ///
    /// 평소 조회에서는 정렬하지 않고,
    /// 실제로 메모리 상한을 초과했을 때만 오래된 순서를 계산한다.
    private func evictIfNeeded() {
        guard totalCost > costLimit else {
            return
        }

        // lastUsed가 작은 항목 = 가장 오래 사용하지 않은 항목.
        let oldestFirst = entries
            .sorted { $0.value.lastUsed < $1.value.lastUsed }
            .map(\.key)

        for key in oldestFirst {
            guard totalCost > costLimit else {
                break
            }

            let removed = entries.removeValue(forKey: key)
            totalCost -= removed?.cost ?? 0
        }
    }
}
