@preconcurrency import AVFoundation
import CameraFeature
import CoreImage
import Observation
import os

/// 데모앱 전용 실기기 카메라 세션. `AVCaptureSession` 구성·필터 프리뷰·촬영·사진첩 저장을 전담한다.
///
/// 프리뷰는 `AVCaptureVideoDataOutput` 프레임에 LUT(`CameraFilterCatalog`)를 입혀
/// `onPreviewImage`(feature의 `CameraPreviewFrameSource` 통로)로 내보낸다.
///
/// 스레드 규칙: 세션 구성·입력 교체·촬영은 `sessionQueue`, 프레임 콜백·프리뷰 LUT는 `videoQueue`
/// 에서만 처리한다 (Apple 권장 — 메인 스레드에서 하면 프리뷰가 멎는다).
@Observable
final class CameraSessionController: NSObject, CameraPreviewFrameSource, @unchecked Sendable {

    enum Authorization: Equatable {
        case notDetermined
        case authorized
        case denied
    }

    let session = AVCaptureSession()

    private(set) var authorization: Authorization = .notDetermined

    /// LUT가 적용된 프리뷰 프레임 콜백. `videoQueue`에서 불린다 — 소비자(렌더러)가 스레드를 넘긴다.
    /// 등록·해제(메인)와 호출(`videoQueue`)의 스레드가 달라 락으로 보호한다.
    var onPreviewImage: (@Sendable (CIImage) -> Void)? {
        get { onPreviewImageState.withLock { $0 } }
        set { onPreviewImageState.withLock { $0 = newValue } }
    }

    private let onPreviewImageState = OSAllocatedUnfairLock<(@Sendable (CIImage) -> Void)?>(initialState: nil)

    // AVFoundation이 GCD를 직접 요구해 async/await로 대체할 수 없는 예외다 —
    // 세션 구성은 전용 시리얼 큐 사용이 Apple 권장이고, 프레임 콜백은 setSampleBufferDelegate(_:queue:)가 큐를 받는다.
    private let sessionQueue = DispatchQueue(label: "com.challa.camerafeaturedemo.session")
    private let videoQueue = DispatchQueue(label: "com.challa.camerafeaturedemo.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var photoCaptureContinuation: CheckedContinuation<Data, Error>?
    /// 프리뷰 프레임에 입힐 LUT. `videoQueue` 전용 — 교체도 큐로 넘겨서 락 없이 안전하다.
    private var previewLUT: (CIFilter & CIColorCubeWithColorSpace)?

    func start(position: CameraPosition) async {
        let granted = await requestAccessIfNeeded()
        await MainActor.run { authorization = granted ? .authorized : .denied }
        guard granted else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [self] in
                configureSessionIfNeeded()
                updateInput(position: position)
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func setCameraPosition(_ position: CameraPosition) {
        sessionQueue.async { [self] in
            updateInput(position: position)
        }
    }

    func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async { [self] in
            guard let device = currentInput?.device else { return }
            let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        }
    }

    /// 프리뷰에 실시간으로 입힐 필터를 바꾼다. nil이면 원본 그대로.
    func setPreviewFilter(id: CameraFilter.ID?) {
        videoQueue.async { [self] in
            previewLUT = id.flatMap { CameraFilterCatalog.lutFilter(id: $0) }
        }
    }

    /// 촬영 후 선택 필터를 입힌 JPEG을 사진첩(Add-only)에 저장한다. `PHPhotoLibraryAddOnly` 권한만
    /// 요구한다 — 추가만 하면 되므로 `PhotoLibrary` 모듈의 읽기·선택 권한(`.readWrite`)까지는 필요 없다.
    func captureAndSavePhoto(flashMode: CameraFlashMode, filterID: CameraFilter.ID?) async throws {
        let data = try await capturePhotoData(flashMode: flashMode)
        let filtered = CameraFilterCatalog.filteredJPEG(from: data, filterID: filterID) ?? data
        try await PhotoLibrarySaver.save(jpegData: filtered)
    }

    private func capturePhotoData(flashMode: CameraFlashMode) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                photoCaptureContinuation = continuation
                let settings = AVCapturePhotoSettings()
                if photoOutput.supportedFlashModes.contains(flashMode.avFlashMode) {
                    settings.flashMode = flashMode.avFlashMode
                }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func requestAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    /// 세션 큐에서만 호출한다.
    private func configureSessionIfNeeded() {
        guard !session.outputs.contains(photoOutput) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        session.commitConfiguration()
    }

    /// 세션 큐에서만 호출한다.
    private func updateInput(position: CameraPosition) {
        guard currentInput?.device.position != position.avPosition else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let currentInput {
            session.removeInput(currentInput)
        }
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }

        session.addInput(input)
        currentInput = input
        configureConnections(position: position)
    }

    /// 입력을 갈아끼우면 연결이 새로 생기므로 그때마다 다시 잡는다. 세션 큐에서만 호출한다.
    private func configureConnections(position: CameraPosition) {
        // 프리뷰 레이어 없이 직접 프레임을 다루므로 세로 회전도 직접 지정한다 (앱은 세로 고정)
        for connection in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)] {
            guard let connection, connection.isVideoRotationAngleSupported(90) else { continue }
            connection.videoRotationAngle = 90
        }
        // 전면 프리뷰만 거울상 — 시스템 카메라와 동일 (저장본은 photoOutput 기본값 유지)
        if let preview = videoOutput.connection(with: .video), preview.isVideoMirroringSupported {
            preview.automaticallyAdjustsVideoMirroring = false
            preview.isVideoMirrored = position == .front
        }
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        if let previewLUT {
            previewLUT.inputImage = image
            image = previewLUT.outputImage ?? image
        }
        onPreviewImage?(image)
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let continuation = photoCaptureContinuation else { return }
        photoCaptureContinuation = nil

        if let error {
            continuation.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation() {
            continuation.resume(returning: data)
        } else {
            continuation.resume(throwing: CameraSessionError.noImageData)
        }
    }
}

enum CameraSessionError: LocalizedError {
    case noImageData

    var errorDescription: String? {
        "촬영한 사진 데이터를 만들지 못했어요."
    }
}

private extension CameraFlashMode {

    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .on: .on
        case .off: .off
        }
    }
}

private extension CameraPosition {

    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .back: .back
        case .front: .front
        }
    }
}
