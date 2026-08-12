@preconcurrency import AVFoundation
import CameraFeature
import Observation

/// 데모앱 전용 실기기 카메라 세션. `AVCaptureSession` 구성·촬영·사진첩 저장을 전담한다.
///
/// 세션 구성·입력 교체·촬영은 전용 시리얼 큐에서만 처리한다 (Apple 권장 — 메인 스레드에서 하면 프리뷰가 멎는다).
@Observable
final class CameraSessionController: NSObject, @unchecked Sendable {

    enum Authorization: Equatable {
        case notDetermined
        case authorized
        case denied
    }

    let session = AVCaptureSession()

    private(set) var authorization: Authorization = .notDetermined

    private let sessionQueue = DispatchQueue(label: "com.challa.camerafeaturedemo.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var photoCaptureContinuation: CheckedContinuation<Data, Error>?

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

    /// 촬영 후 JPEG 데이터를 사진첩(Add-only)에 저장한다. `PHPhotoLibraryAddOnly` 권한만 요구한다 —
    /// 촬영한 사진을 추가만 하면 되므로 `PhotoLibrary` 모듈의 읽기·선택 권한(`.readWrite`)까지는 필요 없다.
    func captureAndSavePhoto(flashMode: CameraFlashMode) async throws {
        let data = try await capturePhotoData(flashMode: flashMode)
        try await PhotoLibrarySaver.save(jpegData: data)
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
