import Foundation

/// 다운샘플된 이미지 바이트를 디스크에 보관하는 캐시.
///
/// 파일 I/O와 LRU 용량 관리라는 가변 상태를 다루므로 `actor`로 동시 접근을 직렬화한다.
/// 파일명은 키의 SHA256 식별자를 쓰고, 용량 초과 시 오래 안 쓴 파일부터(LRU) 삭제한다.
public actor DiskImageCache {

    private let directory: URL
    private let capacityBytes: Int
    private let fileManager = FileManager.default

    public init(directory: URL, capacityBytes: Int) throws {
        self.directory = directory
        self.capacityBytes = capacityBytes
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// 캐시에 있으면 바이트를 반환하고, 없으면 nil. 적중 시 수정일을 지금으로 갱신해
    /// LRU 삭제 순서에서 뒤로 밀리게 한다.
    public func data(for key: ImageCacheKey) -> Data? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        // 최근에 쓴 것으로 표시해 LRU 삭제에서 뒤로 밀리게 한다.
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    /// 바이트를 저장하고, 용량을 넘으면 오래된 것부터 삭제한다.
    public func store(_ data: Data, for key: ImageCacheKey) {
        try? data.write(to: fileURL(for: key))
        evictIfNeeded()
    }

    /// 모든 캐시 파일을 삭제한다. (로그아웃·삭제 감지 시 상위 계층이 호출)
    public func removeAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// 현재 디스크 캐시가 차지한 총 바이트.
    public func totalBytes() -> Int {
        entries().reduce(0) { $0 + $1.size }
    }

    // MARK: - Private

    /// 키의 SHA256 식별자를 파일명으로 써서 캐시 파일 경로를 만든다.
    /// 저장과 조회가 같은 규칙을 쓰므로 별도 색인 없이 키만으로 파일을 찾는다.
    private func fileURL(for key: ImageCacheKey) -> URL {
        directory.appendingPathComponent(key.storageIdentifier)
    }

    /// 용량 초과 시 수정일이 오래된 파일부터 상한 이하가 될 때까지 삭제한다(LRU).
    /// 개별 삭제 실패는 무시한다 — 다음 방출 때 디렉터리를 다시 읽으므로 그때 재시도된다.
    private func evictIfNeeded() {
        var files = entries()
        var total = files.reduce(0) { $0 + $1.size }
        guard total > capacityBytes else { return }

        files.sort { $0.date < $1.date } // 오래된 것 먼저
        for file in files {
            guard total > capacityBytes else { break }
            try? fileManager.removeItem(at: file.url)
            total -= file.size
        }
    }

    /// 캐시 디렉터리의 파일별 (경로, 크기, 수정일) 목록 추출
    /// 크기·수정일을 못 읽은 파일은 용량 합산·LRU 정렬을 할 수 없으므로 제외한다.
    private func entries() -> [FileInfo] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys
        ) else { return [] }

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let size = values.fileSize,
                  let date = values.contentModificationDate
            else { return nil }
            return FileInfo(url: url, size: size, date: date)
        }
    }

    /// 방출 계산에 쓰는 파일 정보.
    private struct FileInfo {
        let url: URL
        let size: Int
        let date: Date
    }
}
