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
/// 2. 같은 키의 진행 중 작업이 있으면 그 결과를 공유(중복 제거)
/// 3. 디스크 히트 → 디코딩·메모리 승격 후 반환 (디코딩 실패 시 조용히 네트워크로 폴백)
/// 4. 네트워크 → 다운샘플 → HEIC 인코딩 → 디스크 저장 + 메모리 저장 후 반환
public actor ImageLoader {

    // MARK: - Properties

    private let memory: MemoryImageCache
    private let disk: DiskImageCache
    private let downsampler: ImageDownsampler
    private let encoder: ImageDataEncoder
    private let fetcher: ImageDataFetching

    /// 일시적 전송 실패 시 재시도 간격(지수 백오프). 원소 개수 = 최대 재시도 횟수.
    private let retryDelays: [Duration]

    /// 같은 키에 대한 중복 다운로드를 막는 진행 중 작업 맵.
    private var inFlight: [ImageCacheKey: Task<UIImage, Error>] = [:]

    // MARK: - Initialization

    /// - Parameters:
    ///   - configuration: 메모리·디스크 캐시 용량과 저장 위치.
    ///   - fetcher: 원격 바이트 취득기. 기본값은 URLCache를 끈 세션 기반 구현.
    ///   - retryDelays: 일시적 전송 실패 시 재시도 간격(지수 백오프). 기본 1→2→4초, 빈 배열이면 재시도 안 함.
    /// - Throws: 디스크 캐시 디렉터리 생성 실패 시 던진다.
    public init(
        configuration: ImageCacheConfiguration = .default,
        fetcher: ImageDataFetching = URLSessionImageDataFetcher(),
        retryDelays: [Duration] = [.seconds(1), .seconds(2), .seconds(4)]
    ) throws {
        self.memory = MemoryImageCache(costLimit: configuration.memoryCostLimitBytes)
        self.disk = try DiskImageCache(
            directory: configuration.diskDirectory,
            capacityBytes: configuration.diskCapacityBytes
        )
        self.downsampler = ImageDownsampler()
        self.encoder = ImageDataEncoder()
        self.fetcher = fetcher
        self.retryDelays = retryDelays
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

        // 3. 중복 제거: 같은 키가 이미 진행 중이면 그 결과를 기다려 공유한다.
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
        defer {
            if inFlight[key] == task {
                inFlight[key] = nil
            }
        }

        do {
            let image = try await task.value
            // 이 호출(뷰)이 취소돼도 위의 await task.value는 에러 없이 이미지를 돌려준다.
            // 그래서 여기서 "내가 취소됐는지"를 직접 확인해, 취소된 호출에는 이미지 대신 .cancelled를 던진다.
            // (다운로드 작업은 일부러 취소하지 않는다 — 끝까지 받아 캐시에 넣어두면 다음 요청이 재사용)
            try Task.checkCancellation()
            return image
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
           let decoded = await Self.decodeCachedData(diskData, scale: scale) {
            memory.insert(decoded.image, for: key, cost: decoded.cost)
            return decoded.image
        }

        // 네트워크. 일시적 전송 실패는 지수 백오프로 재시도한다.
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

        // 다운샘플 + HEIC 인코딩은 액터 밖에서 실행한다.
        let processed = try await downsample(data: data, pointSize: pointSize, scale: scale)

        await disk.store(processed.encodedData, for: key)
        memory.insert(processed.image, for: key, cost: processed.cost)
        return processed.image
    }

    /// 재시도해도 소용 있는(일시적) 전송 실패 코드. 이 외의 URLError는 재시도 없이 즉시 실패한다.
    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .timedOut, .cannotConnectToHost, .cannotFindHost,
        .networkConnectionLost, .notConnectedToInternet,
        .dnsLookupFailed, .badServerResponse
    ]

    /// `fetcher.fetch`를 감싸 일시적 실패 시 `retryDelays` 간격으로 재시도한다.
    ///
    /// - 취소(`.cancelled`)는 재시도하지 않고 `.cancelled`로 종료한다.
    /// - 재시도 불가 코드(예: `.badURL`)거나 재시도 횟수를 소진하면 `.networkFailed`로 실패한다.
    /// - 백오프 대기 중 취소되면 `Task.sleep`이 취소를 던져 상위에서 `.cancelled`로 매핑된다.
    private func fetchWithRetry(_ url: URL) async throws -> (Data, URLResponse) {
        var attempt = 0
        while true {
            do {
                return try await fetcher.fetch(url)
            } catch let error as URLError {
                if error.code == .cancelled {
                    throw ImageLoadingError.cancelled
                }
                guard Self.retryableURLErrorCodes.contains(error.code),
                      attempt < retryDelays.count
                else {
                    throw ImageLoadingError.networkFailed(error.code)
                }
                try await Task.sleep(for: retryDelays[attempt]) // 1초 → 2초 → 4초
                attempt += 1
            }
        }
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
            // 다운샘플은 pt×scale 픽셀을 만든다. scale을 실어야 UIImage.size가 논리 pt로 잡힌다.
            let image = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
            return ProcessedImage(image: image, encodedData: encodedData, cost: cost)
        }.value
    }

    /// 디스크에 저장된(이미 다운샘플된) 바이트를 `UIImage`로 디코딩한다. (액터 밖 유틸리티 우선순위)
    ///
    /// 다운샘플은 불필요하다 — 저장 시점에 이미 타깃 픽셀로 줄여 두었기 때문이다.
    /// 실패 시 `nil`을 반환해 상위에서 네트워크로 폴백하게 한다.
    private static func decodeCachedData(_ data: Data, scale: CGFloat) async -> CachedImage? {
        await Task.detached(priority: .utility) {
            let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options)
            else {
                return nil
            }
            let cost = cgImage.bytesPerRow * cgImage.height
            // 요청 컨텍스트의 scale을 실어 표시 크기를 논리 pt로 맞춘다(네트워크 경로와 동일).
            let image = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
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
