import Foundation

/// 이미지 캐시의 메모리·디스크 정책을 정의한다.
///
/// 앱에서는 `.default`를 사용하고,
/// 테스트에서는 용량과 저장 위치를 직접 주입할 수 있다.
public struct ImageCacheConfiguration: Sendable {

    // MARK: - Properties

    /// 메모리 이미지 캐시의 최대 비용(Byte).
    ///
    /// JPEG·HEIC 압축 크기가 아니라
    /// 디코딩된 이미지의 비트맵 메모리 비용을 기준으로 한다.
    public let memoryCostLimitBytes: Int

    /// 디스크 캐시 저장 위치.
    public let diskDirectory: URL

    /// 디스크 캐시 최대 용량(Byte).
    public let diskCapacityBytes: Int

    /// 디스크 캐시 파일의 최대 보관 기간.
    public let diskRetention: TimeInterval

    /// 현재 서버의 방 보관 정책을 기준으로 한 기본 보관 기간: 30일.
    /// 서버의 만료 기준이나 보관 기간이 변경되면 함께 재검토한다.
    public static let defaultDiskRetention: TimeInterval =
        30 * 24 * 60 * 60

    // MARK: - Initialization

    public init(
        memoryCostLimitBytes: Int,
        diskDirectory: URL,
        diskCapacityBytes: Int,
        diskRetention: TimeInterval = ImageCacheConfiguration.defaultDiskRetention
    ) {
        self.memoryCostLimitBytes = memoryCostLimitBytes
        self.diskDirectory = diskDirectory
        self.diskCapacityBytes = diskCapacityBytes
        self.diskRetention = diskRetention
    }

    // MARK: - Default Configuration

    /// 앱에서 사용하는 기본 이미지 캐시 정책.
    ///
    /// - 메모리: 기기 전체 RAM의 10%, 최대 512MB
    /// - 디스크: 최대 500MB
    /// - 보관 기간: 30일
    /// - 저장 위치: `Caches/CHALLAImageCache`
    ///
    /// 메모리 비율은 OS가 앱에 보장한 메모리 비율이 아니라,
    /// 기기 사양에 따라 캐시 상한을 조절하기 위한 정책값이다.
    ///
    /// 디스크 캐시는 재다운로드 가능한 데이터이므로 `Caches`에 저장하고,
    /// 평상시 용량은 `DiskImageCache`의 LRU 정책으로 직접 관리한다.
    public static var `default`: ImageCacheConfiguration {
        let cachesDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory

        return ImageCacheConfiguration(
            memoryCostLimitBytes: defaultMemoryCostLimit(
                physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory
            ),
            diskDirectory: cachesDirectory.appendingPathComponent(
                "CHALLAImageCache",
                isDirectory: true
            ),
            diskCapacityBytes: 500 * 1024 * 1024,
            diskRetention: defaultDiskRetention
        )
    }

    // MARK: - Memory Policy

    /// 기기 전체 RAM의 10%를 기준으로 하되 최대 512MB로 제한한다.
    ///
    /// `physicalMemoryBytes`는 앱에 할당된 메모리 한도가 아니라
    /// 기기에 설치된 전체 물리 RAM 크기다.
    ///
    /// 예:
    /// - 3GB → 약 307MB
    /// - 4GB → 약 410MB
    /// - 6GB 이상 → 최대 512MB
    static func defaultMemoryCostLimit(
        physicalMemoryBytes: UInt64
    ) -> Int {
        let ratioBased = Double(physicalMemoryBytes) * memoryRatio

        return Int(
            min(
                ratioBased,
                Double(maximumMemoryCostLimit)
            )
        )
    }

    /// 메모리 캐시 상한 계산에 사용할 기기 전체 RAM 비율.
    private static let memoryRatio = 0.10

    /// 고사양 기기에서 캐시가 과도하게 커지는 것을 막는 최대값.
    private static let maximumMemoryCostLimit =
        512 * 1024 * 1024
}
