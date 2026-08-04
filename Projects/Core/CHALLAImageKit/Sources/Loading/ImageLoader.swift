import CoreGraphics
import Foundation
import ImageIO
import UIKit

/// 원격 이미지를 "메모리 → 디스크 → 네트워크" 순으로 해결해 표시용 `UIImage`를 돌려주는 로더.
///
/// 가변 상태(진행 중 작업 맵)와 여러 캐시 계층 조율을 하므로 `actor`로 접근을 직렬화한다.
/// 무거운 CPU 작업(다운샘플·인코딩·디코딩)은 `Task.detached`로 액터 밖에서 실행해 액터가 막히지 않게 한다.
///
/// 파이프라인:
/// 1. 메모리 히트 → 즉시 반환
/// 2. 같은 키의 진행 중 작업이 있으면 그 결과를 공유(dedup)
/// 3. 디스크 히트 → 디코딩·메모리 승격 후 반환 (디코딩 실패 시 조용히 네트워크로 폴백)
/// 4. 네트워크 → 다운샘플 → HEIC 인코딩 → 디스크 저장 + 메모리 저장 후 반환
public actor ImageLoader {

    // MARK: - Properties

    private let memory: MemoryImageCache
    private let disk: DiskImageCache
    private let downsampler: ImageDownsampler
    private let encoder: ImageDataEncoder
    private let fetcher: ImageDataFetching

    /// 같은 키에 대한 중복 다운로드를 막기 위한 진행 중 작업 맵(dedup).
    private var inFlight: [ImageCacheKey: Task<UIImage, Error>] = [:]

    // MARK: - Initialization

    /// - Parameters:
    ///   - configuration: 메모리·디스크 캐시 용량과 저장 위치.
    ///   - fetcher: 원격 바이트 취득기. 기본값은 URLCache를 끈 세션 기반 구현.
    /// - Throws: 디스크 캐시 디렉터리 생성 실패 시 던진다.
    public init(
        configuration: ImageCacheConfiguration = .default,
        fetcher: ImageDataFetching = URLSessionImageDataFetcher()
    ) throws {
        self.memory = MemoryImageCache(costLimit: configuration.memoryCostLimitBytes)
        self.disk = try DiskImageCache(
            directory: configuration.diskDirectory,
            capacityBytes: configuration.diskCapacityBytes
        )
        self.downsampler = ImageDownsampler()
        self.encoder = ImageDataEncoder()
        self.fetcher = fetcher
    }

    // MARK: - Public Methods

    /// URL의 이미지를 표시 크기에 맞춰 로드한다.
    ///
    /// - Parameters:
    ///   - url: 원격 이미지 URL.
    ///   - pointSize: 표시 뷰의 논리 크기(pt).
    ///   - scale: 디스플레이 배율(@2x/@3x).
    /// - Returns: 다운샘플된 표시용 `UIImage`.
    /// - Throws: ``ImageLoadingError``.
    public func image(from url: URL, pointSize: CGSize, scale: CGFloat) async throws -> UIImage {
        let key = ImageCacheKey(url: url, pixelSize: PixelSize(pointSize: pointSize, scale: scale))

        // 1·2. 메모리 히트 → 즉시 반환.
        if let cached = memory.image(for: key) {
            return cached
        }

        // 3. dedup: 같은 키가 이미 진행 중이면 그 결과를 기다려 공유한다.
        if let existing = inFlight[key] {
            do {
                let image = try await existing.value
                try Task.checkCancellation()
                return image
            } catch is CancellationError {
                throw ImageLoadingError.cancelled
            }
        }

        // 4. 새 작업 등록. 성공·실패·취소 모든 경로에서 맵을 정리한다(defer).
        let task = Task<UIImage, Error> { [self] in
            try await load(url: url, key: key, pointSize: pointSize, scale: scale)
        }
        inFlight[key] = task
        // 자기 task일 때만 제거한다. removeAll()이 맵을 비운 사이 다른 요청이
        // 같은 키로 새 task를 등록했을 수 있으므로, 무조건 지우면 남의 등록을 오염시킨다.
        defer { if inFlight[key] == task { inFlight[key] = nil } }

        do {
            return try await task.value
        } catch is CancellationError {
            throw ImageLoadingError.cancelled
        }
    }

    /// 모든 진행 중 작업을 취소하고 메모리·디스크 캐시를 비운다. (로그아웃·메모리 경고 시)
    public func removeAll() async {
        for task in inFlight.values {
            task.cancel()
        }
        inFlight.removeAll()
        memory.removeAll()
        await disk.removeAll()
    }

    // MARK: - Private Methods

    /// 디스크·네트워크를 거쳐 이미지를 실제로 해결한다.
    private func load(
        url: URL,
        key: ImageCacheKey,
        pointSize: CGSize,
        scale: CGFloat
    ) async throws -> UIImage {
        // 디스크 히트: 이미 다운샘플된 바이트이므로 다운샘플 없이 디코딩만 한다.
        // 디코딩에 실패해도 hard-fail 하지 않고 조용히 네트워크로 폴백한다.
        if let diskData = await disk.data(for: key),
           let decoded = await Self.decodeCachedData(diskData) {
            memory.insert(decoded.image, for: key, cost: decoded.cost)
            return decoded.image
        }

        // 네트워크.
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await fetcher.fetch(url)
        } catch let error as URLError {
            // 취소로 인한 전송 중단은 취소로 표면화한다.
            if error.code == .cancelled { throw ImageLoadingError.cancelled }
            throw ImageLoadingError.networkFailed(error.code)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ImageLoadingError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ImageLoadingError.httpStatus(http.statusCode)
        }
        guard !data.isEmpty else {
            throw ImageLoadingError.emptyData
        }

        try Task.checkCancellation()

        // 다운샘플 + HEIC 인코딩은 액터 밖에서 실행한다.
        let processed = try await downsample(data: data, pointSize: pointSize, scale: scale)

        await disk.store(processed.encodedData, for: key)
        memory.insert(processed.image, for: key, cost: processed.cost)
        return processed.image
    }

    /// 원본 바이트를 다운샘플하고 HEIC로 재인코딩한다. (액터 밖 유틸리티 우선순위)
    ///
    /// 동시성: 이 detached 클로저는 Sendable 값만 캡처한다(`ImageDownsampler`, `ImageDataEncoder`,
    /// `Data`, `CGSize`, `CGFloat`). 비-Sendable인 `CGImage`는 클로저 내부에서만 존재하며 밖으로 새지 않고,
    /// 결과로는 `ProcessedImage`(다운샘플 완료 후 불변인 `UIImage` + 바이트 + cost)만 돌려준다.
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
                cgImage = try downsampler.downsample(data: data, pointSize: pointSize, scale: scale)
            } catch let error as ImageDownsamplingError {
                throw ImageLoadingError.downsampling(error)
            }

            let encodedData = try encoder.encode(cgImage)
            let cost = cgImage.bytesPerRow * cgImage.height
            let image = UIImage(cgImage: cgImage)
            return ProcessedImage(image: image, encodedData: encodedData, cost: cost)
        }.value
    }

    /// 디스크에 저장된(이미 다운샘플된) 바이트를 `UIImage`로 디코딩한다. (액터 밖 유틸리티 우선순위)
    ///
    /// 다운샘플은 불필요하다 — 저장 시점에 이미 타깃 픽셀로 줄여 두었기 때문이다.
    /// 실패 시 `nil`을 반환해 상위에서 네트워크로 폴백하게 한다.
    private static func decodeCachedData(_ data: Data) async -> CachedImage? {
        await Task.detached(priority: .utility) {
            let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options)
            else {
                return nil
            }
            let cost = cgImage.bytesPerRow * cgImage.height
            let image = UIImage(cgImage: cgImage)
            return CachedImage(image: image, cost: cost)
        }.value
    }
}

// MARK: - Detached Result Types

private extension ImageLoader {

    /// 네트워크 경로의 detached 결과: 표시용 이미지 + 디스크 저장용 바이트 + 메모리 cost.
    struct ProcessedImage {
        let image: UIImage
        let encodedData: Data
        let cost: Int
    }

    /// 디스크 경로의 detached 결과: 표시용 이미지 + 메모리 cost.
    struct CachedImage {
        let image: UIImage
        let cost: Int
    }
}
