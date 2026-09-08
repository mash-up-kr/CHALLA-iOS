import CoreGraphics
import Foundation
import ImageIO
import UIKit

/// 원격 이미지를 표시 크기에 맞게 로드하고
/// 메모리·디스크·네트워크 캐시 계층을 조율한다.
///
/// 이미지 로드 순서:
/// 1. 메모리 캐시
/// 2. 동일 키의 진행 중 작업 공유
/// 3. 디스크 캐시
/// 4. 네트워크 → 다운샘플 → JPEG 저장
///
/// 진행 중 작업과 메모리 캐시는 `ImageLoader` actor에서 관리하고,
/// 다운샘플·인코딩·디코딩은 `Task.detached`에서 수행한다.
public actor ImageLoader {

    // MARK: - Properties

    /// 다운샘플된 `UIImage`를 보관하는 메모리 LRU 캐시.
    private let memory: MemoryImageCache

    /// 다운샘플 후 JPEG로 인코딩한 바이트를 보관하는 디스크 캐시.
    private let disk: DiskImageCache

    private let downsampler: ImageDownsampler
    private let encoder: ImageDataEncoder
    /// 배치 다운로더와 공유하는 재시도·응답 검증 로직.
    private let transfer: RemoteImageData

    /// 동일한 캐시 키에 대해 현재 진행 중인 이미지 로드 작업.
    ///
    /// 같은 URL과 PixelSize 요청이 동시에 들어오면
    /// 새 작업을 만들지 않고 기존 Task의 결과를 공유한다.
    private var inFlight: [ImageCacheKey: Task<UIImage, Error>] = [:]

    // MARK: - Initialization

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
        self.transfer = RemoteImageData(fetcher: fetcher, retryDelays: retryDelays)
    }

    // MARK: - Public Methods

    /// URL의 이미지를 실제 표시 크기에 맞춰 로드한다.
    ///
    /// 같은 URL이라도 표시 크기가 다르면 필요한 픽셀 수가 다르므로
    /// URL과 PixelSize를 함께 캐시 키로 사용한다.
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

        // 캐시 적중 여부와 관계없이 취소된 호출은 동일하게 .cancelled로 처리한다.
        if let cached = memory.image(for: key) {
            guard !Task.isCancelled else {
                throw ImageLoadingError.cancelled
            }

            return cached
        }

        // 같은 이미지 로드가 진행 중이면 기존 작업의 결과를 공유한다.
        if let existing = inFlight[key] {
            do {
                let image = try await existing.value

                // 공유 작업과 현재 호출자의 취소 상태는 별개다.
                try Task.checkCancellation()

                return image
            } catch is CancellationError {
                throw ImageLoadingError.cancelled
            }
        }

        let task = Task<UIImage, Error> { [self] in
            try await load(
                url: url,
                key: key,
                pointSize: pointSize,
                scale: scale
            )
        }

        inFlight[key] = task

        // removeAll() 이후 같은 키에 새 Task가 등록될 수 있으므로
        // 현재 등록된 작업이 내가 만든 Task일 때만 제거한다.
        defer {
            if inFlight[key] == task {
                inFlight[key] = nil
            }
        }

        do {
            let image = try await task.value

            // 공유 로드는 캐시에 남기되 취소된 호출자에게 결과를 반환하지 않는다.
            try Task.checkCancellation()

            return image
        } catch is CancellationError {
            throw ImageLoadingError.cancelled
        }
    }

    /// 메모리 캐시만 비운다.
    ///
    /// 메모리 경고는 App 레이어에서 받고 이 메서드를 호출한다.
    /// 디스크 캐시와 진행 중인 다운로드는 유지한다.
    public func evictMemoryCache() {
        memory.removeAll()
    }

    /// 보관 기간을 넘긴 디스크 캐시 파일을 정리한다.
    /// 호출 시점은 App 레이어가 결정한다.
    public func removeExpiredDiskCache() async {
        await disk.removeExpired()
    }

    /// 진행 중인 작업을 취소하고 메모리·디스크 캐시를 모두 비운다.
    public func removeAll() async {
        for task in inFlight.values {
            task.cancel()
        }

        inFlight.removeAll()
        memory.removeAll()

        await disk.removeAll()
    }

    // MARK: - Loading Pipeline

    /// 메모리 캐시 이후의 실제 이미지 로드 파이프라인.
    ///
    /// 디스크에 없거나 디코딩에 실패하면 네트워크에서 다시 받아
    /// 다운샘플 후 메모리·디스크 캐시에 저장한다.
    private func load(
        url: URL,
        key: ImageCacheKey,
        pointSize: CGSize,
        scale: CGFloat
    ) async throws -> UIImage {

        // 디스크에는 이미 목표 PixelSize로 다운샘플된 데이터가 있으므로
        // 다시 다운샘플하지 않고 디코딩만 한다.
        if let diskData = await disk.data(for: key),
           let decoded = await Self.decodeCachedData(
               diskData,
               scale: scale
           ) {
            memory.insert(
                decoded.image,
                for: key,
                cost: decoded.cost
            )

            return decoded.image
        }

        let data = try await transfer.data(from: url)

        try Task.checkCancellation()

        let processed = try await downsample(
            data: data,
            pointSize: pointSize,
            scale: scale
        )

        await disk.store(
            processed.encodedData,
            for: key
        )

        memory.insert(
            processed.image,
            for: key,
            cost: processed.cost
        )

        return processed.image
    }

    // MARK: - Image Processing

    /// 원본 이미지를 요청 크기로 다운샘플하고 JPEG로 인코딩한다.
    ///
    /// CPU 비용이 있는 이미지 처리는 `Task.detached(.utility)`에서 수행한다.
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

            // 압축 파일 크기가 아닌 디코딩된 비트맵의 메모리 비용.
            let cost = cgImage.bytesPerRow * cgImage.height

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

    /// 디스크에 저장된 다운샘플 이미지를 `UIImage`로 디코딩한다.
    ///
    /// 디코딩에 실패하면 `nil`을 반환해 네트워크 경로로 폴백한다.
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

            let cost = cgImage.bytesPerRow * cgImage.height

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

    /// 네트워크 처리 결과.
    /// 화면 표시·메모리 캐시·디스크 캐시에 필요한 값을 함께 전달한다.
    struct ProcessedImage {
        let image: UIImage
        let encodedData: Data
        let cost: Int
    }

    /// 디스크 캐시에서 복구한 이미지와 메모리 비용.
    struct CachedImage {
        let image: UIImage
        let cost: Int
    }
}
