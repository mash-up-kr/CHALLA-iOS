import CoreGraphics
import Foundation
import ImageIO
import UIKit

/// 원격 이미지를 표시 크기에 맞게 로드하고
/// 메모리·디스크·네트워크 캐시 계층을 조율한다.
///
/// `actor`로 메모리 캐시와 진행 중 작업 상태를 직렬화해
/// 동일한 이미지 요청이 동시에 들어와도 중복 다운로드가 발생하지 않도록 한다.
///
/// 이미지 로드 순서:
/// 1. 메모리 캐시
/// 2. 동일 키의 진행 중 작업 공유
/// 3. 디스크 캐시
/// 4. 네트워크 다운로드 → 다운샘플 → HEIC 저장
///
/// 다운샘플·인코딩·디코딩처럼 CPU 비용이 큰 이미지 처리는
/// `Task.detached`에서 수행해 `ImageLoader` actor가 오래 점유되지 않도록 한다.
public actor ImageLoader {

    // MARK: - Properties

    /// 다운샘플된 `UIImage`를 보관하는 메모리 LRU 캐시.
    private let memory: MemoryImageCache

    /// 다운샘플 후 HEIC로 인코딩한 이미지 바이트를 보관하는 디스크 캐시.
    private let disk: DiskImageCache

    /// 원본 이미지를 실제 표시 크기에 맞게 줄이는 다운샘플러.
    private let downsampler: ImageDownsampler

    /// 다운샘플된 이미지를 디스크 저장용 HEIC 바이트로 변환한다.
    private let encoder: ImageDataEncoder

    /// 원격 URL에서 원본 이미지 바이트를 가져온다.
    private let fetcher: ImageDataFetching

    /// 일시적인 네트워크 실패가 발생했을 때 사용할 재시도 간격.
    ///
    /// 배열의 원소 개수가 최대 재시도 횟수이며,
    /// 빈 배열을 주입하면 재시도하지 않는다.
    private let retryDelays: [Duration]

    /// 동일한 캐시 키에 대해 현재 진행 중인 이미지 로드 작업.
    ///
    /// 같은 URL과 같은 PixelSize를 여러 View가 동시에 요청하면
    /// 새 다운로드를 만들지 않고 기존 Task의 결과를 공유한다.
    private var inFlight: [ImageCacheKey: Task<UIImage, Error>] = [:]

    // MARK: - Initialization

    /// 이미지 로더를 생성한다.
    ///
    /// - Parameters:
    ///   - configuration:
    ///     메모리·디스크 캐시 용량, 디스크 위치, 보관 기간 정책.
    ///   - fetcher:
    ///     원격 이미지 바이트를 가져오는 구현.
    ///   - retryDelays:
    ///     일시적인 네트워크 실패 시 사용할 재시도 간격.
    ///     기본값은 1초 → 2초 → 4초다.
    ///
    /// - Throws:
    ///   디스크 캐시 디렉터리를 생성할 수 없으면 에러를 던진다.
    public init(
        configuration: ImageCacheConfiguration = .default,
        fetcher: ImageDataFetching = URLSessionImageDataFetcher(),
        retryDelays: [Duration] = [
            .seconds(1),
            .seconds(2),
            .seconds(4)
        ]
    ) throws {
        self.memory = MemoryImageCache(
            costLimit: configuration.memoryCostLimitBytes
        )

        self.disk = try DiskImageCache(
            directory: configuration.diskDirectory,
            capacityBytes: configuration.diskCapacityBytes,
            retention: configuration.diskRetention
        )

        self.downsampler = ImageDownsampler()
        self.encoder = ImageDataEncoder()
        self.fetcher = fetcher
        self.retryDelays = retryDelays
    }

    // MARK: - Public Methods

    /// URL의 이미지를 실제 표시 크기에 맞춰 로드한다.
    ///
    /// 동일한 URL이라도 표시 크기가 다르면 필요한 픽셀 수가 다르므로
    /// URL과 PixelSize를 함께 캐시 키로 사용한다.
    ///
    /// - Parameters:
    ///   - url:
    ///     원격 이미지 URL.
    ///   - pointSize:
    ///     SwiftUI/UIKit에서 실제로 표시할 논리 크기(pt).
    ///   - scale:
    ///     현재 디스플레이 배율(@2x/@3x).
    ///
    /// - Returns:
    ///   표시 크기에 맞게 다운샘플된 `UIImage`.
    ///
    /// - Throws:
    ///   이미지 로드 과정에서 발생한 ``ImageLoadingError``.
    public func image(
        from url: URL,
        pointSize: CGSize,
        scale: CGFloat
    ) async throws -> UIImage {
        let key = ImageCacheKey(
            url: url,
            pixelSize: PixelSize(
                pointSize: pointSize,
                scale: scale
            )
        )

        // 메모리 캐시
        //
        // 가장 빠른 경로다.
        // 이미 디코딩된 UIImage가 있으므로 별도 I/O나 이미지 처리 없이 반환한다.
        //
        // 다른 반환 지점과 마찬가지로 호출자의 취소 상태를 먼저 확인한다.
        // 이 경로만 확인을 생략하면 같은 요청이라도 캐시 적중 여부에 따라
        // 취소된 호출이 이미지를 받기도, .cancelled를 받기도 한다.
        if let cached = memory.image(for: key) {
            guard !Task.isCancelled else {
                throw ImageLoadingError.cancelled
            }

            return cached
        }

        // 진행 중 작업 공유
        //
        // 같은 이미지가 이미 디스크 또는 네트워크에서 로드되고 있다면
        // 새 작업을 만들지 않고 기존 Task의 결과를 기다린다.
        if let existing = inFlight[key] {
            do {
                let image = try await existing.value

                // 공유 Task와 현재 호출자의 취소 상태는 별개이므로
                // 결과를 돌려주기 전에 현재 호출자가 취소됐는지 확인한다.
                try Task.checkCancellation()

                return image
            } catch is CancellationError {
                throw ImageLoadingError.cancelled
            }
        }

        // 메모리에도 없고 진행 중 작업도 없으므로
        // 디스크 → 네트워크 경로를 담당할 새로운 로드 작업을 등록한다.
        let task = Task<UIImage, Error> { [self] in
            try await load(
                url: url,
                key: key,
                pointSize: pointSize,
                scale: scale
            )
        }

        inFlight[key] = task

        // 현재 등록된 작업이 내가 생성한 Task일 때만 제거한다.
        //
        // removeAll()이 맵을 비운 뒤 같은 키로 새로운 Task가 등록된 경우,
        // 이전 요청의 defer가 새 Task의 등록까지 지우는 것을 막는다.
        defer {
            if inFlight[key] == task {
                inFlight[key] = nil
            }
        }

        do {
            let image = try await task.value

            // 현재 View의 요청이 취소되더라도 공유 이미지 Task는
            // 끝까지 실행해 캐시에 결과를 남길 수 있다.
            //
            // 다만 이미 취소된 호출자에게는 결과를 전달하지 않기 위해
            // 반환 직전에 현재 호출자의 취소 상태를 확인한다.
            try Task.checkCancellation()

            return image
        } catch is CancellationError {
            throw ImageLoadingError.cancelled
        }
    }

    /// 메모리 이미지 캐시를 전부 비운다.
    ///
    /// iOS가 메모리 부족 경고를 보내면 App 레이어에서 호출한다.
    ///
    /// 메모리의 `UIImage`만 제거하고,
    /// 디스크 캐시와 진행 중인 이미지 다운로드는 유지한다.
    ///
    /// 이후 같은 이미지가 필요하면 디스크 캐시에서 다시 복구할 수 있고,
    /// 디스크에도 없다면 네트워크에서 다시 가져온다.
    public func evictMemoryCache() {
        memory.removeAll()
    }

    /// 보관 기간을 넘긴 디스크 캐시 파일을 정리한다.
    ///
    /// 디스크 용량 초과 여부와 관계없는 시간 기반 정리이며,
    /// 실제 호출 시점은 App 레이어에서 결정한다.
    public func removeExpiredDiskCache() async {
        await disk.removeExpired()
    }

    /// 모든 이미지 로드 작업과 캐시를 초기화한다.
    ///
    /// 현재 진행 중인 다운로드를 취소하고,
    /// 메모리 캐시와 디스크 캐시를 모두 제거한다.
    ///
    /// 로그아웃처럼 사용자 데이터 전체 정리가 필요한 상황에서 사용한다.
    public func removeAll() async {
        for task in inFlight.values {
            task.cancel()
        }

        inFlight.removeAll()
        memory.removeAll()

        await disk.removeAll()
    }

    // MARK: - Loading Pipeline

    /// 메모리 캐시 이후의 실제 이미지 로드 파이프라인을 수행한다.
    ///
    /// 순서:
    /// 1. 디스크 캐시 확인
    /// 2. 디스크 미스 또는 디코딩 실패 시 네트워크 요청
    /// 3. 원본 이미지 다운샘플
    /// 4. HEIC 인코딩
    /// 5. 디스크·메모리 캐시에 저장
    private func load(
        url: URL,
        key: ImageCacheKey,
        pointSize: CGSize,
        scale: CGFloat
    ) async throws -> UIImage {

        // 디스크 캐시
        //
        // 디스크에는 이미 요청한 PixelSize에 맞게 다운샘플된 HEIC가 저장되어 있다.
        // 따라서 다시 다운샘플하지 않고 UIImage로 디코딩만 한다.
        //
        // 디스크 파일이 손상되어 디코딩할 수 없는 경우에는
        // 사용자에게 에러를 바로 노출하지 않고 네트워크 경로로 폴백한다.
        if let diskData = await disk.data(for: key),
           let decoded = await Self.decodeCachedData(
               diskData,
               scale: scale
           ) {
            // 디스크에서 복구한 UIImage를 메모리 캐시에 승격한다.
            memory.insert(
                decoded.image,
                for: key,
                cost: decoded.cost
            )

            return decoded.image
        }

        // 네트워크
        //
        // 일시적인 전송 실패는 retryDelays 정책에 따라 재시도한다.
        let (data, response) = try await fetchWithRetry(url)

        guard let http = response as? HTTPURLResponse else {
            throw ImageLoadingError.invalidResponse
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            throw ImageLoadingError.httpStatus(http.statusCode)
        }

        guard !data.isEmpty else {
            throw ImageLoadingError.emptyData
        }

        try Task.checkCancellation()

        // 네트워크에서 받은 원본 이미지를 실제 표시 크기로 다운샘플하고,
        // 디스크 저장을 위해 HEIC 바이트도 함께 만든다.
        let processed = try await downsample(
            data: data,
            pointSize: pointSize,
            scale: scale
        )

        // 디스크에는 압축된 HEIC 바이트를 저장한다.
        await disk.store(
            processed.encodedData,
            for: key
        )

        // 메모리에는 바로 표시할 수 있는 UIImage를 저장한다.
        memory.insert(
            processed.image,
            for: key,
            cost: processed.cost
        )

        return processed.image
    }

    // MARK: - Network Retry

    /// 재시도했을 때 성공 가능성이 있는 일시적인 네트워크 에러 코드.
    ///
    /// 잘못된 URL처럼 재시도로 해결되지 않는 오류는 포함하지 않는다.
    ///
    /// `notConnectedToInternet`도 포함하지 않는다.
    /// 이 코드는 시스템이 사용할 수 있는 네트워크 인터페이스가 없다고 판단한 결과이므로
    /// 몇 초 안에 상황이 달라질 가능성이 낮다.
    /// 포함하면 오프라인에서 매 요청마다 백오프 시간만큼 대기한 뒤 실패하게 된다.
    ///
    /// 반면 `networkConnectionLost`는 연결이 있던 상태에서 전송 도중 끊긴 경우라
    /// 재시도할 가치가 있다.
    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotConnectToHost,
        .cannotFindHost,
        .networkConnectionLost,
        .dnsLookupFailed,
        .badServerResponse
    ]

    /// 원격 이미지 요청을 수행하고 일시적인 실패라면 지수 백오프로 재시도한다.
    ///
    /// 기본 설정에서는:
    ///
    /// 첫 실패 → 1초 대기
    /// 두 번째 실패 → 2초 대기
    /// 세 번째 실패 → 4초 대기
    ///
    /// - 취소는 재시도하지 않고 즉시 `.cancelled`로 종료한다.
    /// - 재시도할 수 없는 오류는 즉시 `.networkFailed`로 종료한다.
    /// - 재시도 횟수를 모두 사용한 경우 마지막 오류를 `.networkFailed`로 변환한다.
    private func fetchWithRetry(
        _ url: URL
    ) async throws -> (Data, URLResponse) {
        var attempt = 0

        while true {
            do {
                return try await fetcher.fetch(url)
            } catch let error as URLError {
                if error.code == .cancelled {
                    throw ImageLoadingError.cancelled
                }

                guard
                    Self.retryableURLErrorCodes.contains(error.code),
                    attempt < retryDelays.count
                else {
                    throw ImageLoadingError.networkFailed(error.code)
                }

                // Task.sleep은 취소에 반응한다.
                // 백오프 대기 중 호출자가 취소되면 CancellationError가 상위로 전달된다.
                try await Task.sleep(
                    for: retryDelays[attempt]
                )

                attempt += 1
            }
        }
    }

    // MARK: - Image Processing

    /// 원본 이미지 바이트를 요청한 표시 크기에 맞게 다운샘플하고 HEIC로 인코딩한다.
    ///
    /// 디코딩·다운샘플·인코딩은 CPU 비용이 있을 수 있으므로
    /// `Task.detached`에서 실행한다.
    ///
    /// 한 번의 처리 결과에서:
    /// - `UIImage`는 화면 표시와 메모리 캐시에 사용하고
    /// - HEIC 바이트는 디스크 캐시에 저장하며
    /// - cost는 메모리 캐시 용량 계산에 사용한다.
    private func downsample(
        data: Data,
        pointSize: CGSize,
        scale: CGFloat
    ) async throws -> ProcessedImage {
        let downsampler = self.downsampler
        let encoder = self.encoder

        return try await Task.detached(priority: .utility) {
            let cgImage: CGImage

            do {
                cgImage = try downsampler.downsample(
                    data: data,
                    pointSize: pointSize,
                    scale: scale
                )
            } catch let error as ImageDownsamplingError {
                throw ImageLoadingError.downsampling(error)
            }

            let encodedData = try encoder.encode(cgImage)

            // 압축된 HEIC 파일 크기가 아니라,
            // 디코딩된 비트맵이 메모리에서 차지하는 크기를 cost로 사용한다.
            let cost = cgImage.bytesPerRow * cgImage.height

            // 다운샘플러는 pointSize × scale에 해당하는 픽셀 이미지를 만든다.
            //
            // UIImage에도 동일한 scale을 전달해야
            // UIImage.size가 실제 표시용 논리 pt 크기로 계산된다.
            let image = UIImage(
                cgImage: cgImage,
                scale: scale,
                orientation: .up
            )

            return ProcessedImage(
                image: image,
                encodedData: encodedData,
                cost: cost
            )
        }.value
    }

    /// 디스크 캐시에 저장된 이미지 바이트를 `UIImage`로 디코딩한다.
    ///
    /// 디스크에는 이미 목표 픽셀 크기로 다운샘플된 이미지가 저장되어 있으므로
    /// 추가적인 다운샘플링은 하지 않는다.
    ///
    /// 디코딩에 실패하면 `nil`을 반환해
    /// 상위 로드 파이프라인이 네트워크로 폴백하도록 한다.
    private static func decodeCachedData(
        _ data: Data,
        scale: CGFloat
    ) async -> CachedImage? {
        await Task.detached(priority: .utility) {
            let options = [
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary

            guard
                let source = CGImageSourceCreateWithData(
                    data as CFData,
                    nil
                ),
                let cgImage = CGImageSourceCreateImageAtIndex(
                    source,
                    0,
                    options
                )
            else {
                return nil
            }

            // 메모리 캐시의 cost 계산 기준을
            // 네트워크 경로와 동일하게 맞춘다.
            let cost = cgImage.bytesPerRow * cgImage.height

            // 요청 당시 사용한 scale을 다시 적용해
            // 네트워크 경로와 동일한 논리 pt 크기의 UIImage를 만든다.
            let image = UIImage(
                cgImage: cgImage,
                scale: scale,
                orientation: .up
            )

            return CachedImage(
                image: image,
                cost: cost
            )
        }.value
    }
}

// MARK: - Detached Result Types

private extension ImageLoader {

    /// 네트워크 이미지 처리 결과.
    ///
    /// 한 번의 다운샘플 결과를 화면 표시·메모리 캐시·디스크 캐시에
    /// 각각 재사용하기 위해 필요한 값을 묶는다.
    struct ProcessedImage {
        /// 화면 표시 및 메모리 캐시에 사용할 이미지.
        let image: UIImage

        /// 디스크 캐시에 저장할 HEIC 바이트.
        let encodedData: Data

        /// 디코딩된 이미지의 메모리 비용.
        let cost: Int
    }

    /// 디스크 캐시 디코딩 결과.
    ///
    /// 디스크에서 복구한 이미지를 메모리 캐시에 승격하기 위해
    /// 이미지와 메모리 비용을 함께 반환한다.
    struct CachedImage {
        let image: UIImage
        let cost: Int
    }
}
