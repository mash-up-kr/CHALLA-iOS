import Foundation

/// 다운샘플된 이미지 바이트를 디스크에 보관하는 LRU 캐시.
///
/// 파일 I/O와 용량 관리 상태를 하나의 `actor` 안에서 관리해
/// 동시에 여러 요청이 들어와도 저장·조회·삭제가 서로 충돌하지 않도록 한다.
///
/// 파일명은 `ImageCacheKey.storageIdentifier`를 사용하며,
/// 캐시가 용량 상한을 넘으면 오래 사용하지 않은 파일부터 제거한다.
///
/// 디스크 전체 스캔 비용을 줄이기 위해 매 저장마다 실제 용량을 계산하지 않는다.
/// 마지막으로 확인한 용량에 이후 저장된 바이트를 더한 `estimatedTotalBytes`를 유지하고,
/// 이 값이 상한을 넘었을 때만 디렉터리를 다시 읽어 실제 용량을 확인한다.
///
/// 방출 시에는 두 가지 정책을 적용한다.
/// - 상한을 넘으면 90% 지점까지 한 번에 정리해 반복적인 스캔을 줄인다.
/// - 썸네일·그리드처럼 작은 이미지는 일정 용량까지 보호해,
///   큰 이미지 하나 때문에 작은 이미지 여러 장이 한꺼번에 밀려나는 것을 줄인다.
public actor DiskImageCache {

    private let directory: URL
    private let capacityBytes: Int
    private let fileManager = FileManager.default

    /// 마지막 디렉터리 스캔에서 확인한 용량에
    /// 이후 저장된 바이트를 더해 관리하는 추정 용량.
    ///
    /// 매 저장마다 디렉터리를 스캔하지 않기 위한 값이며,
    /// 실제 용량보다 커질 수 있다.
    ///
    /// 예:
    /// - 같은 키를 덮어쓴 경우
    /// - OS가 `Caches`의 일부 파일을 삭제한 경우
    ///
    /// 이런 과대 추정은 스캔을 조금 일찍 발생시킬 뿐이며,
    /// 다음 스캔에서 실제 디스크 용량으로 다시 교정된다.
    private var estimatedTotalBytes: Int?

    /// 디렉터리를 실제로 스캔한 횟수.
    ///
    /// 매 저장마다 전체 디렉터리를 읽지 않는다는 것을 테스트하기 위한 값이다.
    private(set) var directoryReadCount = 0

    /// 용량 초과 시 파일 삭제를 멈출 목표 지점.
    ///
    /// 500MB 캐시라면 약 450MB까지 줄인다.
    /// 상한 바로 아래까지만 정리하면 다음 몇 번의 저장에서 다시 스캔할 수 있으므로
    /// 일정 여유 공간을 확보한다.
    private var evictionTargetBytes: Int {
        capacityBytes * 9 / 10
    }

    /// 작은 이미지가 우선적으로 유지될 수 있도록 확보한 용량.
    ///
    /// 전체 디스크 캐시의 10%를 사용한다.
    /// 기본 500MB 설정에서는 50MB가 된다.
    ///
    /// 별도의 물리적인 저장 공간을 만드는 것은 아니며,
    /// 방출 후보를 정할 때 최근 사용한 작은 이미지들을 이 용량만큼 보호한다.
    private var smallImageReserveBytes: Int {
        capacityBytes / 10
    }

    /// 파일 크기가 이 값보다 작으면 썸네일·그리드 계열의 작은 이미지로 취급한다.
    ///
    /// 현재 다운샘플·HEIC 저장 결과를 기준으로
    /// 작은 이미지와 상세 이미지의 크기 분포를 구분하기 위한 정책값이다.
    ///
    /// 픽셀 크기가 아니라 파일 크기를 사용하는 이유는
    /// 방출 시 이미 파일 크기를 읽고 있어 추가적인 디스크 I/O가 필요하지 않기 때문이다.
    private static let smallImageThresholdBytes = 100 * 1024

    public init(
        directory: URL,
        capacityBytes: Int
    ) throws {
        self.directory = directory
        self.capacityBytes = capacityBytes

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    /// 캐시에 저장된 데이터를 반환한다.
    ///
    /// 캐시 적중 시 파일 수정일을 현재 시각으로 갱신한다.
    /// 수정일은 LRU의 마지막 사용 시각으로 사용되므로,
    /// 방금 조회한 파일은 다음 방출에서 뒤쪽으로 밀린다.
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

    /// 데이터를 디스크에 저장한다.
    ///
    /// 매 저장마다 디렉터리 전체를 읽지 않고 추정 용량만 증가시킨다.
    /// 추정 용량이 상한을 넘었을 때만 실제 디스크 용량을 다시 계산하고
    /// 필요한 경우 LRU 방출을 수행한다.
    ///
    /// 실행 후 첫 저장에서는 기존 캐시가 얼마나 남아 있는지 알 수 없으므로
    /// 한 번 디렉터리를 스캔해 기준 용량을 만든다.
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
    ///
    /// 로그아웃이나 상위 계층에서 전체 캐시 삭제가 필요하다고 판단했을 때 호출한다.
    public func removeAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        estimatedTotalBytes = 0
    }

    /// 현재 디스크 캐시의 실제 총 용량(Byte)을 계산한다.
    ///
    /// 디렉터리를 직접 스캔하므로 진단·테스트처럼
    /// 실제 용량 확인이 필요한 경우에 사용한다.
    public func totalBytes() -> Int {
        entries().reduce(0) { $0 + $1.size }
    }

    // MARK: - Private

    /// 캐시 키의 저장 식별자를 파일명으로 사용해 파일 경로를 만든다.
    ///
    /// 저장과 조회가 같은 규칙을 사용하므로 별도의 파일 인덱스가 필요하지 않다.
    private func fileURL(for key: ImageCacheKey) -> URL {
        directory.appendingPathComponent(key.storageIdentifier)
    }

    /// 실제 디스크 용량을 확인하고, 상한을 넘으면 LRU 방출을 수행한다.
    ///
    /// 스캔한 시점의 실제 용량으로 `estimatedTotalBytes`를 교정하고,
    /// 용량이 초과된 경우 `evictionTargetBytes`까지 파일을 제거한다.
    private func evictIfNeeded() {
        let files = entries()
        var total = files.reduce(0) { $0 + $1.size }

        // 실제 디스크를 확인했으므로 추정값을 정확한 값으로 교정한다.
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
                // 삭제 실패 시 파일은 여전히 존재하므로 총량을 유지한다.
                // 이후 용량이 다시 상한을 넘으면 다음 스캔에서 재시도된다.
            }
        }

        estimatedTotalBytes = total
    }

    /// 방출 가능한 파일을 오래된 순서로 반환한다.
    ///
    /// 큰 이미지는 모두 방출 후보가 된다.
    ///
    /// 작은 이미지는 최근 사용한 파일부터 `smallImageReserveBytes`만큼 보호하고,
    /// 그 범위를 초과한 오래된 파일만 방출 후보에 포함한다.
    ///
    /// 따라서 작은 이미지가 예약 용량 안에 있는 동안에는
    /// 큰 이미지가 먼저 방출되고, 예약 용량을 초과한 이후부터
    /// 오래된 작은 이미지도 일반 LRU 대상이 된다.
    private func evictionCandidates(
        from files: [FileInfo]
    ) -> [FileInfo] {
        let oldestFirst = files.sorted {
            $0.date < $1.date
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
        for file in small.reversed() {
            reservedBytes += file.size

            if reservedBytes > smallImageReserveBytes {
                evictableSmall.append(file)
            }
        }

        // 최종 삭제 순서는 다시 전체 후보의 LRU 순서를 따른다.
        return (large + evictableSmall)
            .sorted { $0.date < $1.date }
    }

    /// 캐시 디렉터리의 파일 목록과 용량·수정일을 읽는다.
    ///
    /// 파일 크기는 전체 캐시 용량 계산에,
    /// 수정일은 LRU 순서 계산에 사용한다.
    ///
    /// 필요한 메타데이터를 읽지 못한 파일은
    /// 정확한 용량 및 LRU 판단이 불가능하므로 제외한다.
    private func entries() -> [FileInfo] {
        directoryReadCount += 1

        let keys: Set<URLResourceKey> = [
            .fileSizeKey,
            .contentModificationDateKey
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
                let date = values.contentModificationDate
            else {
                return nil
            }

            return FileInfo(
                url: url,
                size: size,
                date: date
            )
        }
    }

    /// LRU 방출 계산에 필요한 최소 파일 정보.
    private struct FileInfo {
        let url: URL
        let size: Int
        let date: Date
    }
}
