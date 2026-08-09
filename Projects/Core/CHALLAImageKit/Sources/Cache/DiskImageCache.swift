import Foundation

/// 다운샘플된 이미지 바이트를 디스크에 보관하는 LRU 캐시.
///
/// 파일 I/O와 용량 관리 상태를 `actor`로 직렬화한다.
/// 매 저장마다 디렉터리를 스캔하지 않고 추정 용량을 유지하며,
/// 상한을 넘었을 때 실제 용량을 확인해 LRU 방출을 수행한다.
///
/// 방출 시에는 상한의 90%까지 여유를 만들고,
/// 최근 사용한 작은 이미지는 일정 용량까지 우선 보호한다.
/// 보관 기간을 넘긴 파일은 용량과 별개로 정리한다.
public actor DiskImageCache {

    // MARK: - Properties

    private let directory: URL
    private let capacityBytes: Int
    private let fileManager = FileManager.default

    /// 마지막 디렉터리 스캔 이후의 디스크 사용량 추정치.
    ///
    /// 같은 키 덮어쓰기나 OS의 `Caches` 정리로 실제보다 커질 수 있으며,
    /// 다음 스캔에서 실제 값으로 교정한다.
    private var estimatedTotalBytes: Int?

    /// 디렉터리를 실제로 스캔한 횟수.
    /// 저장마다 전체 스캔하지 않는다는 것을 테스트할 때 사용한다.
    private(set) var directoryReadCount = 0

    /// 용량 초과 시 방출을 멈출 목표값.
    /// 상한 바로 아래에서 반복적으로 스캔하지 않도록 90%까지 정리한다.
    private var evictionTargetBytes: Int {
        capacityBytes * 9 / 10
    }

    /// 최근 사용한 작은 이미지를 우선 보호할 용량.
    ///
    /// 별도 디스크 공간을 예약하는 것이 아니라
    /// 방출 후보를 정할 때 전체 용량의 10%만큼 보호한다.
    private var smallImageReserveBytes: Int {
        capacityBytes / 10
    }

    /// 작은 이미지로 분류할 파일 크기 기준.
    ///
    /// 현재 HEIC 결과에서 썸네일·그리드와 상세 이미지의
    /// 크기 분포를 구분하기 위한 정책값이다.
    private static let smallImageThresholdBytes = 100 * 1024

    /// 파일 생성 시각을 기준으로 적용할 최대 보관 기간.
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

    /// 캐시된 이미지 바이트를 반환한다.
    ///
    /// 적중 시 수정일을 현재 시각으로 갱신해
    /// LRU의 마지막 사용 시각으로 활용한다.
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
    /// 첫 저장에서 실제 용량을 한 번 확인한 뒤,
    /// 이후에는 추정 용량이 상한을 넘을 때만 디렉터리를 다시 스캔한다.
    public func store(
        _ data: Data,
        for key: ImageCacheKey
    ) {
        try? data.write(to: fileURL(for: key))

        guard let estimated = estimatedTotalBytes else {
            evictIfNeeded()
            return
        }

        let updated = estimated + data.count
        estimatedTotalBytes = updated

        guard updated > capacityBytes else {
            return
        }

        evictIfNeeded()
    }

    /// 디스크 캐시의 모든 파일을 제거한다.
    public func removeAll() {
        try? fileManager.removeItem(at: directory)

        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        estimatedTotalBytes = 0
    }

    /// 보관 기간을 넘긴 파일을 제거한다.
    ///
    /// 수정일은 캐시 적중 때마다 갱신되므로 만료 기준으로 사용할 수 없다.
    /// 파일 생성 시각을 기준으로 판정하며, 용량 기반 LRU와 별도로 동작한다.
    public func removeExpired() {
        let deadline = Date().addingTimeInterval(-retention)

        for file in entries() where file.createdAt < deadline {
            try? fileManager.removeItem(at: file.url)
        }

        // 삭제 후 기존 추정 용량이 부정확해지므로 다음 저장에서 다시 측정한다.
        estimatedTotalBytes = nil
    }

    /// 현재 디스크 캐시의 실제 총 용량(Byte).
    /// 디렉터리를 직접 스캔하므로 주로 진단·테스트에 사용한다.
    public func totalBytes() -> Int {
        entries().reduce(0) { $0 + $1.size }
    }

    // MARK: - Eviction

    /// 실제 디스크 용량을 확인하고 상한을 넘으면 목표 용량까지 방출한다.
    private func evictIfNeeded() {
        let files = entries()
        var total = files.reduce(0) { $0 + $1.size }

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

                // 실제 삭제에 성공한 경우에만 총량을 줄인다.
                total -= file.size
            } catch {
                // 삭제 실패 시 파일은 남아 있으므로 총량도 유지한다.
            }
        }

        estimatedTotalBytes = total
    }

    /// 방출 가능한 파일을 LRU 순서로 반환한다.
    ///
    /// 큰 이미지는 모두 후보로 두고,
    /// 최근 사용한 작은 이미지는 예약 용량만큼 후보에서 제외한다.
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

        // 최근 작은 이미지부터 예약 용량을 채운다.
        for file in small.reversed() {
            reservedBytes += file.size

            if reservedBytes > smallImageReserveBytes {
                evictableSmall.append(file)
            }
        }

        // 보호 대상이 아닌 파일들 사이에서는 다시 LRU 순서를 따른다.
        return (large + evictableSmall)
            .sorted { $0.lastUsedAt < $1.lastUsedAt }
    }

    // MARK: - File Metadata

    private func fileURL(for key: ImageCacheKey) -> URL {
        directory.appendingPathComponent(key.storageIdentifier)
    }

    /// 용량·LRU·만료 판정에 필요한 파일 메타데이터를 읽는다.
    ///
    /// - 파일 크기: 용량 계산 및 작은/큰 이미지 분류
    /// - 수정일: LRU 마지막 사용 시각
    /// - 생성일: 보관 기간 판정
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

                // 생성일을 읽지 못하면 수정일을 사용해 조기 만료를 피한다.
                createdAt: values.creationDate ?? lastUsedAt
            )
        }
    }

    private struct FileInfo {
        let url: URL
        let size: Int

        /// LRU 방출 기준.
        let lastUsedAt: Date

        /// 보관 기간 만료 기준.
        let createdAt: Date
    }
}
