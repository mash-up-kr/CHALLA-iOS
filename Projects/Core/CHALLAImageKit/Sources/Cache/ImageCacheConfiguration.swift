import Foundation

/// 이미지 캐시(메모리·디스크)의 용량·저장 위치 설정.
///
/// 캐시 코드에 숫자를 하드코딩하지 않고 이 꾸러미로 주입해,
/// 실제 앱은 `.default`를 쓰고 테스트는 작은 용량을 넣어 LRU 동작을 검증할 수 있게 한다.
public struct ImageCacheConfiguration: Sendable {

    /// 메모리 캐시 총 비용 상한 (바이트). NSCache가 이 값을 넘으면 오래된 항목을 방출한다.
    public let memoryCostLimitBytes: Int

    /// 디스크 캐시 파일이 저장될 디렉터리.
    public let diskDirectory: URL

    /// 디스크 캐시 총 용량 상한 (바이트). 초과 시 LRU로 오래된 파일부터 삭제한다.
    public let diskCapacityBytes: Int

    public init(memoryCostLimitBytes: Int, diskDirectory: URL, diskCapacityBytes: Int) {
        self.memoryCostLimitBytes = memoryCostLimitBytes
        self.diskDirectory = diskDirectory
        self.diskCapacityBytes = diskCapacityBytes
    }

    /// 앱에서 쓰는 기본 설정. 메모리 100MB, 디스크 500MB, Caches 디렉터리 하위에 저장.
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
