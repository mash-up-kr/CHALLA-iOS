import Foundation

/// 이미지 캐시의 메모리·디스크 정책을 정의한다.
///
/// 앱에서는 `.default`를 사용하고,
/// 테스트에서는 작은 용량이나 임시 디렉터리를 직접 주입해
/// 용량 제한·LRU·만료 정리 동작을 검증할 수 있다.
public struct ImageCacheConfiguration: Sendable {

    // MARK: - Properties

    /// 메모리 이미지 캐시가 유지할 수 있는 최대 비용(Byte).
    ///
    /// 저장된 이미지들의 총 cost가 이 값을 넘으면
    /// `MemoryImageCache`가 가장 오래 사용하지 않은 이미지부터 제거한다.
    ///
    /// 여기서 cost는 JPEG·HEIC 같은 압축 파일 크기가 아니라
    /// 디코딩된 이미지가 메모리에서 차지하는 비트맵 비용을 의미한다.
    public let memoryCostLimitBytes: Int

    /// 디스크 캐시 파일을 저장할 디렉터리.
    public let diskDirectory: URL

    /// 디스크 캐시가 사용할 수 있는 최대 용량(Byte).
    ///
    /// 상한을 넘으면 `DiskImageCache`가
    /// LRU 정책에 따라 오래 사용하지 않은 파일부터 제거한다.
    public let diskCapacityBytes: Int

    /// 디스크 캐시 파일을 유지할 최대 기간.
    ///
    /// `DiskImageCache.removeExpired()`가 파일 생성 시각과 이 값을 비교해
    /// 보관 기간을 넘긴 파일을 제거한다.
    public let diskRetention: TimeInterval

    /// 기본 디스크 캐시 보관 기간: 30일.
    ///
    /// 현재 서버의 방 보관 정책을 기준으로 한 값이며,
    /// 서버의 만료 기준이나 보관 기간 정책이 변경되면 함께 재검토한다.
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

    // MARK: - Default

    /// 앱에서 사용하는 기본 이미지 캐시 설정.
    ///
    /// - 메모리: 기기 전체 RAM의 10%, 최대 512MB
    /// - 디스크: 최대 500MB
    /// - 디스크 보관 기간: 30일
    /// - 저장 위치: `Caches/CHALLAImageCache`
    ///
    /// 메모리의 10%는 OS가 앱에 보장한 메모리 비율이 아니다.
    /// 기기 사양에 따라 이미지 캐시 크기를 조절하기 위해
    /// 앱에서 선택한 정책값이다.
    ///
    /// 디스크 캐시는 삭제되어도 다시 다운로드할 수 있는 데이터이므로
    /// `Documents`가 아닌 `Caches` 디렉터리에 저장한다.
    ///
    /// 저장 공간이 부족하면 OS가 `Caches`의 파일을 제거할 수 있지만,
    /// 언제 삭제할지는 보장되지 않는다.
    /// 따라서 평상시 디스크 용량은 `DiskImageCache`의 LRU 정책으로 직접 관리한다.
    public static var `default`: ImageCacheConfiguration {
        let cachesDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory

        return ImageCacheConfiguration(
            memoryCostLimitBytes: defaultMemoryCostLimit(
                physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory
            ),
            diskDirectory: cachesDirectory
                .appendingPathComponent(
                    "CHALLAImageCache",
                    isDirectory: true
                ),
            diskCapacityBytes: 500 * 1024 * 1024,
            diskRetention: defaultDiskRetention
        )
    }

    // MARK: - Memory Policy

    /// 기기 전체 RAM을 기준으로 메모리 이미지 캐시 상한을 계산한다.
    ///
    /// 기본적으로 전체 RAM의 10%를 사용하되,
    /// 고사양 기기에서 캐시가 지나치게 커지는 것을 막기 위해
    /// 최대 512MB까지만 허용한다.
    ///
    /// 예:
    /// - 3GB RAM → 약 307MB
    /// - 4GB RAM → 약 410MB
    /// - 6GB RAM → 약 614MB → 512MB
    /// - 8GB RAM → 약 819MB → 512MB
    ///
    /// `physicalMemoryBytes`는 앱에 할당된 메모리 한도가 아니라
    /// 기기에 설치된 전체 물리 RAM 크기다.
    ///
    /// - Parameter physicalMemoryBytes:
    ///   기기의 전체 물리 메모리 크기(Byte).
    /// - Returns:
    ///   메모리 이미지 캐시에 적용할 최대 비용(Byte).
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

    /// 기기 전체 RAM 중 이미지 메모리 캐시 상한 계산에 사용할 비율.
    ///
    /// OS가 앱에 보장하거나 예약해주는 메모리 비율이 아니라
    /// 캐시 크기를 계산하기 위해 앱에서 정한 정책값이다.
    private static let memoryRatio = 0.10

    /// 고사양 기기에서도 이미지 메모리 캐시가
    /// 지나치게 커지지 않도록 제한하는 최대값.
    private static let maximumMemoryCostLimit =
        512 * 1024 * 1024
}
