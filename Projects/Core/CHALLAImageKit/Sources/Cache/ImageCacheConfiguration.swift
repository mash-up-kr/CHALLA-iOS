import Foundation

/// 이미지 캐시의 메모리 용량, 디스크 용량, 저장 위치를 정의한다.
///
/// 앱에서는 `.default`를 사용하고,
/// 테스트에서는 원하는 용량과 디렉터리를 직접 주입할 수 있다.
public struct ImageCacheConfiguration: Sendable {

    /// 메모리 이미지 캐시가 사용할 수 있는 최대 비용(Byte).
    ///
    /// 저장된 이미지들의 총 cost가 이 값을 넘으면
    /// `MemoryImageCache`가 가장 오래 사용하지 않은 이미지부터 제거한다(LRU).
    public let memoryCostLimitBytes: Int

    /// 디스크 캐시 파일을 저장할 디렉터리.
    public let diskDirectory: URL

    /// 디스크 캐시가 사용할 수 있는 최대 용량(Byte).
    ///
    /// 상한을 넘으면 `DiskImageCache`가
    /// 가장 오래 사용하지 않은 파일부터 제거한다.
    public let diskCapacityBytes: Int

    public init(
        memoryCostLimitBytes: Int,
        diskDirectory: URL,
        diskCapacityBytes: Int
    ) {
        self.memoryCostLimitBytes = memoryCostLimitBytes
        self.diskDirectory = diskDirectory
        self.diskCapacityBytes = diskCapacityBytes
    }

    /// 앱에서 사용하는 기본 캐시 설정.
    ///
    /// - 메모리: 기기 전체 RAM의 10%, 최대 512MB
    /// - 디스크: 최대 500MB
    /// - 저장 위치: `Caches/CHALLAImageCache`
    ///
    /// 메모리의 10%는 OS가 앱에 보장한 메모리 비율이 아니라,
    /// 기기 사양에 따라 캐시 크기를 조절하기 위한 앱의 정책값이다.
    ///
    /// 디스크 캐시는 다시 다운로드할 수 있는 데이터이므로 `Documents`가 아닌
    /// `Caches`에 저장한다. 저장 공간이 부족하면 OS가 해당 파일을 제거할 수 있다.
    ///
    /// 다만 OS가 언제 캐시 파일을 제거할지는 보장되지 않으므로,
    /// 평상시 디스크 용량은 `DiskImageCache`의 500MB LRU 정책으로 직접 관리한다.
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
            diskCapacityBytes: 500 * 1024 * 1024
        )
    }

    /// 기기 전체 RAM을 기준으로 메모리 이미지 캐시의 상한을 계산한다.
    ///
    /// 기본적으로 전체 RAM의 10%를 사용하되,
    /// 고사양 기기에서 이미지 캐시가 지나치게 커지는 것을 막기 위해
    /// 최대 512MB까지만 허용한다.
    ///
    /// 예:
    /// - 3GB RAM → 약 307MB
    /// - 4GB RAM → 약 410MB
    /// - 6GB RAM → 약 614MB → 512MB
    /// - 8GB RAM → 약 819MB → 512MB
    ///
    /// - Parameter physicalMemoryBytes:
    ///   기기의 전체 물리 메모리 크기(Byte).
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
    /// OS가 보장하는 메모리 비율이 아니라 앱에서 정한 캐시 정책값이다.
    private static let memoryRatio = 0.10

    /// 고사양 기기에서도 이미지 메모리 캐시가
    /// 이 값보다 커지지 않도록 제한한다.
    private static let maximumMemoryCostLimit = 512 * 1024 * 1024
}
