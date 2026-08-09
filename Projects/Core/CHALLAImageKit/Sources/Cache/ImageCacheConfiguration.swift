import Foundation

/// 이미지 캐시(메모리·디스크)의 용량·저장 위치 설정.
///
/// 앱은 `.default`를 쓰고, 테스트는 작은 용량을 주입해 상한·LRU 동작을 검증한다.
public struct ImageCacheConfiguration: Sendable {

    /// 메모리 캐시 총 비용 상한(바이트). 초과 시 가장 오래 사용하지 않은 항목부터 방출한다(LRU).
    public let memoryCostLimitBytes: Int

    /// 디스크 캐시 디렉터리. 없으면 `DiskImageCache`가 생성한다.
    public let diskDirectory: URL

    /// 디스크 캐시 총 용량 상한(바이트). 초과 시 수정일이 오래된 파일부터(LRU) 삭제한다.
    /// 수정일은 읽기 적중 때마다 갱신된다.
    public let diskCapacityBytes: Int

    public init(memoryCostLimitBytes: Int, diskDirectory: URL, diskCapacityBytes: Int) {
        self.memoryCostLimitBytes = memoryCostLimitBytes
        self.diskDirectory = diskDirectory
        self.diskCapacityBytes = diskCapacityBytes
    }

    /// 기본 설정 — 메모리 100MB · 디스크 500MB · `Caches/CHALLAImageCache`.
    ///
    /// 디스크 캐시는 `Documents/`가 아닌 `Caches/`에 둔다: 기기 저장 공간이 부족하면
    /// OS가 이 폴더의 파일을 삭제할 수 있고, 지워져도 재다운로드로 다시 채워진다.
    /// 다만 OS 삭제는 언제 일어날지 보장이 없으므로 용량 관리 수단으로 쓰지 않는다.
    /// 평상시 용량은 `DiskImageCache`의 LRU(500MB 상한)가 유지한다.
    /// (메모리 캐시가 cost 상한 초과 시 LRU로 방출하는 것과는 별개 동작)
    public static var `default`: ImageCacheConfiguration {
        let caches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory

        return ImageCacheConfiguration(
            memoryCostLimitBytes: 100 * 1024 * 1024, // 100MB
            diskDirectory: caches.appendingPathComponent("CHALLAImageCache", isDirectory: true),
            diskCapacityBytes: 500 * 1024 * 1024 // 500MB
        )
    }
}
