import Foundation

/// 다운샘플된 이미지 바이트를 디스크에 보관하는 LRU 캐시.
///
/// 파일 저장·조회·삭제와 용량 관리 상태를 하나의 `actor` 안에서 관리해
/// 여러 이미지 요청이 동시에 들어와도 디스크 상태가 서로 충돌하지 않도록 한다.
///
/// 파일명은 `ImageCacheKey.storageIdentifier`를 사용하며,
/// 캐시 용량을 초과하면 마지막 사용 시각이 오래된 파일부터 제거한다.
///
/// 매 저장마다 디렉터리 전체를 읽지는 않는다.
/// 마지막 스캔에서 확인한 용량에 이후 저장된 바이트를 더한 추정치를 유지하고,
/// 이 값이 상한을 넘었을 때만 실제 디스크 용량을 다시 계산한다.
///
/// 방출 시에는 두 가지 정책을 추가로 적용한다.
/// - 용량 초과 시 상한의 90%까지 한 번에 정리해 반복적인 디렉터리 스캔을 줄인다.
/// - 썸네일·그리드처럼 작은 이미지는 일정 용량까지 우선 보호해,
///   큰 이미지 하나 때문에 작은 이미지 여러 장이 한꺼번에 밀려나는 것을 줄인다.
///
/// 용량과 별개로 보관 기간을 넘긴 파일은 `removeExpired()`를 통해 정리한다.
public actor DiskImageCache {

    // MARK: - Properties

    /// 캐시 파일이 저장되는 디렉터리.
    private let directory: URL

    /// 디스크 캐시가 사용할 수 있는 최대 용량(Byte).
    private let capacityBytes: Int

    private let fileManager = FileManager.default

    /// 마지막 디렉터리 스캔 이후의 디스크 사용량 추정치.
    ///
    /// 마지막으로 확인한 실제 용량에 이후 저장된 `data.count`를 더해 관리한다.
    /// 이를 통해 이미지 저장마다 디렉터리 전체를 다시 읽는 비용을 피한다.
    ///
    /// 같은 키를 덮어쓰거나 OS가 `Caches`의 일부 파일을 삭제하면
    /// 실제 용량보다 크게 추정될 수 있다.
    ///
    /// 과대 추정은 디렉터리 스캔을 조금 일찍 발생시킬 뿐이며,
    /// 다음 스캔에서 실제 용량으로 다시 교정된다.
    private var estimatedTotalBytes: Int?

    /// 캐시 디렉터리를 실제로 스캔한 횟수.
    ///
    /// 매 저장마다 디렉터리를 읽지 않는다는 최적화 동작을
    /// 테스트에서 확인하기 위한 계수기다.
    private(set) var directoryReadCount = 0

    /// 용량 초과 시 방출을 멈출 목표 용량.
    ///
    /// 상한 바로 아래까지만 정리하면 몇 번의 저장만으로 다시 상한에 도달할 수 있다.
    /// 따라서 한 번 방출할 때 상한의 90%까지 줄여 다음 스캔까지 여유를 만든다.
    ///
    /// 예: 500MB 캐시 → 약 450MB까지 정리
    private var evictionTargetBytes: Int {
        capacityBytes * 9 / 10
    }

    /// 작은 이미지에 우선적으로 보장할 캐시 용량.
    ///
    /// 전체 디스크 캐시의 10%를 사용한다.
    /// 기본 500MB 설정에서는 50MB가 된다.
    ///
    /// 실제로 디스크 공간을 별도로 분리하는 것은 아니다.
    /// 방출 후보를 정할 때 최근 사용한 작은 이미지들을
    /// 이 용량만큼 삭제 대상에서 제외하는 정책이다.
    private var smallImageReserveBytes: Int {
        capacityBytes / 10
    }

    /// 작은 이미지와 큰 이미지를 구분하는 파일 크기 기준.
    ///
    /// 현재 다운샘플 후 HEIC 파일 크기를 기준으로
    /// 썸네일·그리드 이미지와 상세 이미지의 크기 분포를 나누기 위한 정책값이다.
    ///
    /// 방출 과정에서 파일 크기는 이미 전체 용량 계산을 위해 읽고 있으므로,
    /// 파일 바이트를 기준으로 하면 별도의 메타데이터나 추가 I/O가 필요하지 않다.
    private static let smallImageThresholdBytes = 100 * 1024

    /// 디스크 캐시 파일을 유지할 최대 기간.
    ///
    /// 파일의 생성 시각을 기준으로 `removeExpired()`가 만료 여부를 판단한다.
    private let retention: TimeInterval

    // MARK: - Initialization

    public init(
        directory: URL,
        capacityBytes: Int,
        retention: TimeInterval = ImageCacheConfiguration.defaultDiskRetention
    ) throws {
        self.directory = directory
        self.capacityBytes = capacityBytes
        self.retention = retention

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public Methods

    /// 캐시에 저장된 이미지 바이트를 반환한다.
    ///
    /// 캐시 적중 시 파일의 수정일을 현재 시각으로 갱신한다.
    /// 수정일은 LRU의 마지막 사용 시각으로 사용되므로,
    /// 최근 조회된 파일일수록 방출 순서가 뒤로 밀린다.
    public func data(for key: ImageCacheKey) -> Data? {
        let url = fileURL(for: key)

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )

        return data
    }

    /// 이미지 바이트를 디스크에 저장한다.
    ///
    /// 실행 후 첫 저장에서는 기존 캐시가 얼마나 남아 있는지 알 수 없으므로
    /// 디렉터리를 한 번 스캔해 기준 용량을 만든다.
    ///
    /// 그 이후에는 저장된 바이트만 `estimatedTotalBytes`에 더하고,
    /// 추정치가 용량 상한을 넘었을 때만 실제 디렉터리를 다시 읽는다.
    public func store(
        _ data: Data,
        for key: ImageCacheKey
    ) {
        try? data.write(to: fileURL(for: key))

        // 아직 실제 디스크 용량을 확인한 적이 없다면
        // 첫 저장 시 한 번 스캔해 추정치의 기준을 만든다.
        guard let estimated = estimatedTotalBytes else {
            evictIfNeeded()
            return
        }

        let updated = estimated + data.count
        estimatedTotalBytes = updated

        // 추정 용량이 상한 안이라면 디렉터리를 읽지 않는다.
        guard updated > capacityBytes else {
            return
        }

        // 상한을 넘었다고 추정될 때만 실제 용량을 확인한다.
        evictIfNeeded()
    }

    /// 디스크 캐시의 모든 파일을 제거한다.
    ///
    /// 로그아웃이나 사용자 데이터 전체 정리처럼
    /// 상위 계층에서 전체 캐시 삭제가 필요하다고 판단했을 때 호출한다.
    public func removeAll() {
        try? fileManager.removeItem(at: directory)

        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        estimatedTotalBytes = 0
    }

    /// 보관 기간을 넘긴 디스크 캐시 파일을 제거한다.
    ///
    /// 파일 생성 시각은 사진을 실제로 내려받은 시각에 가깝고,
    /// 방 생성 시각보다 같거나 늦다.
    ///
    /// 따라서 동일한 보관 기간을 적용하면 서버의 방 만료보다
    /// 캐시를 먼저 제거하지 않고, 실제 방 삭제보다 늦게 제거될 수 있다.
    ///
    /// 이 정리는 용량 상한과 관계없는 시간 기반 정리이므로
    /// LRU 용량 방출과 별도의 경로로 실행한다.
    ///
    /// 실제 호출 시점은 App 레이어에서 결정한다.
    public func removeExpired() {
        let deadline = Date().addingTimeInterval(-retention)

        for file in entries() where file.createdAt < deadline {
            try? fileManager.removeItem(at: file.url)
        }

        // 파일이 삭제되면서 기존 추정 용량이 더 이상 정확하지 않으므로
        // 다음 저장에서 실제 디스크 용량을 다시 측정하도록 초기화한다.
        estimatedTotalBytes = nil
    }

    /// 현재 디스크 캐시가 실제로 차지하고 있는 총 용량(Byte)을 반환한다.
    ///
    /// 디렉터리를 직접 스캔하므로 테스트·진단처럼
    /// 실제 용량 확인이 필요한 경우에 사용한다.
    public func totalBytes() -> Int {
        entries().reduce(0) { $0 + $1.size }
    }

    // MARK: - Private Methods

    /// 캐시 키의 저장 식별자를 파일명으로 사용해 파일 경로를 만든다.
    ///
    /// 저장과 조회가 동일한 규칙을 사용하므로
    /// 별도의 파일 인덱스를 유지할 필요가 없다.
    private func fileURL(for key: ImageCacheKey) -> URL {
        directory.appendingPathComponent(key.storageIdentifier)
    }

    /// 실제 디스크 용량을 확인하고 필요하면 LRU 방출을 수행한다.
    ///
    /// 디렉터리를 스캔한 시점의 실제 용량으로 `estimatedTotalBytes`를 교정한다.
    /// 실제 용량이 상한을 넘었다면 `evictionTargetBytes`까지 파일을 제거한다.
    private func evictIfNeeded() {
        let files = entries()
        var total = files.reduce(0) { $0 + $1.size }

        // 실제 디스크를 읽었으므로 추정치를 정확한 값으로 교정한다.
        estimatedTotalBytes = total

        guard total > capacityBytes else {
            return
        }

        for file in evictionCandidates(from: files) {
            guard total > evictionTargetBytes else {
                break
            }

            do {
                try fileManager.removeItem(at: file.url)

                // 실제 삭제에 성공한 경우에만 현재 총량을 줄인다.
                total -= file.size
            } catch {
                // 삭제에 실패했다면 파일은 여전히 존재하므로
                // 총량을 줄이지 않는다.
                //
                // 이후 다시 상한을 넘으면 다음 스캔에서 재시도된다.
            }
        }

        estimatedTotalBytes = total
    }

    /// 용량 방출에 사용할 파일 목록을 LRU 순서로 만든다.
    ///
    /// 큰 이미지는 모두 방출 후보가 된다.
    ///
    /// 작은 이미지는 최근 사용한 파일부터 `smallImageReserveBytes`만큼 보호하고,
    /// 그 범위를 초과한 오래된 파일만 방출 후보에 포함한다.
    ///
    /// 보호 대상이 아닌 파일들 사이에서는
    /// 다시 마지막 사용 시각 기준 LRU 순서를 적용한다.
    private func evictionCandidates(
        from files: [FileInfo]
    ) -> [FileInfo] {
        let oldestFirst = files.sorted {
            $0.lastUsedAt < $1.lastUsedAt
        }

        let small = oldestFirst.filter {
            $0.size < Self.smallImageThresholdBytes
        }

        let large = oldestFirst.filter {
            $0.size >= Self.smallImageThresholdBytes
        }

        var reservedBytes = 0
        var evictableSmall: [FileInfo] = []

        // 최근 사용한 작은 이미지부터 예약 용량을 채운다.
        //
        // small은 오래된 → 최근 순서이므로 reversed()를 사용하면
        // 최근 → 오래된 순서가 된다.
        for file in small.reversed() {
            reservedBytes += file.size

            if reservedBytes > smallImageReserveBytes {
                evictableSmall.append(file)
            }
        }

        // 큰 이미지 + 보호 범위를 벗어난 작은 이미지를 합친 뒤
        // 최종 삭제 순서는 다시 LRU 기준으로 결정한다.
        return (large + evictableSmall)
            .sorted { $0.lastUsedAt < $1.lastUsedAt }
    }

    /// 캐시 디렉터리의 파일 목록과 필요한 메타데이터를 읽는다.
    ///
    /// - 파일 크기: 전체 캐시 용량 계산 및 작은/큰 이미지 분류
    /// - 수정일: 마지막 사용 시각으로 사용해 LRU 순서 계산
    /// - 생성일: 보관 기간 만료 판정
    ///
    /// 수정일은 캐시 적중 때마다 갱신되므로
    /// 파일을 처음 내려받은 시각으로 사용할 수 없다.
    /// 따라서 보관 기간 판정에는 갱신되지 않는 생성일을 사용한다.
    ///
    /// 필요한 메타데이터를 읽을 수 없는 파일은
    /// 정확한 용량 및 LRU 계산이 불가능하므로 목록에서 제외한다.
    private func entries() -> [FileInfo] {
        directoryReadCount += 1

        let keys: Set<URLResourceKey> = [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey
        ]

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys)
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard
                let values = try? url.resourceValues(forKeys: keys),
                let size = values.fileSize,
                let lastUsedAt = values.contentModificationDate
            else {
                return nil
            }

            return FileInfo(
                url: url,
                size: size,
                lastUsedAt: lastUsedAt,

                // 생성일을 읽을 수 없다면 수정일을 대신 사용한다.
                //
                // 수정일은 생성일보다 같거나 늦으므로 파일을 더 최근 것으로 판단하게 되고,
                // 만료 삭제가 늦어질 수는 있어도 더 일찍 삭제하지는 않는다.
                createdAt: values.creationDate ?? lastUsedAt
            )
        }
    }

    // MARK: - FileInfo

    /// LRU 방출과 보관 기간 판정에 필요한 최소 파일 정보.
    private struct FileInfo {
        let url: URL

        /// 디스크에서 차지하는 파일 크기(Byte).
        let size: Int

        /// 마지막 캐시 적중 시각.
        ///
        /// 파일 수정일을 사용하며 LRU 방출 순서 계산에 사용한다.
        let lastUsedAt: Date

        /// 파일이 처음 저장된 시각.
        ///
        /// 파일 생성일을 사용하며 보관 기간 만료 판정에 사용한다.
        let createdAt: Date
    }
}
