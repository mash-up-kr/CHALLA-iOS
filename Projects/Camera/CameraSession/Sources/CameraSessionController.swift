@preconcurrency import AVFoundation
import CameraFeature
import CoreImage
import os
import PhotoDomain

/// 실기기 카메라 세션. `AVCaptureSession` 구성·필터 프리뷰·촬영을 전담한다.
/// 실행 앱(`CHALLAApp`)과 데모앱이 같은 인스턴스 구성을 쓴다.
///
/// 프리뷰는 `AVCaptureVideoDataOutput` 프레임에 LUT(`CameraFilterCatalog`)를 입혀
/// `onPreviewImage`(feature의 `CameraPreviewFrameSource` 통로)로 내보낸다.
///
/// 스레드 규칙: 세션 구성·입력 교체·촬영은 `sessionQueue`, 프레임 콜백·프리뷰 LUT는 `videoQueue`
/// 에서만 처리한다 (Apple 권장 — 메인 스레드에서 하면 프리뷰가 멎는다).
public final class CameraSessionController: NSObject, CameraPreviewFrameSource, @unchecked Sendable {

    public let session = AVCaptureSession()

    override public init() {
        super.init()
    }

    /// LUT가 적용된 프리뷰 프레임 콜백. `videoQueue`에서 불린다 — 소비자(렌더러)가 스레드를 넘긴다.
    /// 등록·해제(메인)와 호출(`videoQueue`)의 스레드가 달라 락으로 보호한다.
    public var onPreviewImage: (@Sendable (CIImage) -> Void)? {
        get { onPreviewImageState.withLock { $0 } }
        set { onPreviewImageState.withLock { $0 = newValue } }
    }

    private let onPreviewImageState = OSAllocatedUnfairLock<(@Sendable (CIImage) -> Void)?>(initialState: nil)

    // AVFoundation이 GCD를 직접 요구해 async/await로 대체할 수 없는 예외다 —
    // 세션 구성은 전용 시리얼 큐 사용이 Apple 권장이고, 프레임 콜백은 setSampleBufferDelegate(_:queue:)가 큐를 받는다.
    private let sessionQueue = DispatchQueue(label: "com.challa.camerasession.session")
    private let videoQueue = DispatchQueue(label: "com.challa.camerasession.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var photoCaptureContinuation: CheckedContinuation<Data, Error>?
    /// 프리뷰 프레임에 입힐 LUT. `videoQueue` 전용 — 교체도 큐로 넘겨서 락 없이 안전하다.
    private var previewLUT: (CIFilter & CIColorCubeWithColorSpace)?
    private var desiredZoomFactor: CGFloat = 1

    /// 세션을 구성하고 돌리기 시작한다. 권한은 진입 버튼이 이미 받아 둔 것을 전제로 한다 —
    /// 허용되지 않은 채로 부르면 입력이 붙지 않아 검은 화면이 남는다.
    public func start(position: CameraPosition) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [self] in
                configureSessionIfNeeded()
                updateInput(position: position)
                // 세션은 화면보다 오래 살아 이전 진입의 배율이 기기에 남는다.
                // 같은 전·후면으로 다시 들어오면 updateInput이 조기 반환하므로 여기서 다시 건다.
                applyZoomFactor()
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
    }

    public func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    public func setCameraPosition(_ position: CameraPosition) {
        sessionQueue.async { [self] in
            updateInput(position: position)
        }
    }

    public func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async { [self] in
            desiredZoomFactor = factor
            applyZoomFactor()
        }
    }

    /// 입력을 갈아끼우면 기기 배율이 1로 돌아가므로, 화면이 들고 있는 배율을 새 기기에 다시 걸어준다.
    /// 세션 큐에서만 호출한다.
    private func applyZoomFactor() {
        guard let device = currentInput?.device else { return }
        let clamped = min(
            max(desiredZoomFactor, device.minAvailableVideoZoomFactor),
            device.maxAvailableVideoZoomFactor
        )
        guard (try? device.lockForConfiguration()) != nil else { return }
        device.videoZoomFactor = clamped
        device.unlockForConfiguration()
    }

    /// 프리뷰에 실시간으로 입힐 필터를 바꾼다. nil이면 원본 그대로.
    public func setPreviewFilter(id: CameraFilter.ID?) {
        videoQueue.async { [self] in
            previewLUT = id.flatMap { CameraFilterCatalog.lutFilter(id: $0) }
        }
    }

    /// 촬영본에 선택 필터를 입힌 JPEG을 돌려준다 — 호출부가 업로드로 잇는다.
    /// 촬영본은 사용자 사진첩에 저장하지 않는다.
    public func capturePhoto(flashMode: CameraFlashMode, filterID: CameraFilter.ID) async throws -> Data {
        let data = try await capturePhotoData(flashMode: flashMode)
        return CameraFilterCatalog.filteredJPEG(from: data, filterID: filterID) ?? data
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

        if let currentInput {
            session.removeInput(currentInput)
        }
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        currentInput = input
        session.commitConfiguration()

        // 센서 방향 판별이 새 입력 기준으로 갱신된 뒤라야 해서 커밋 이후에 연결을 잡는다
        configureConnections(position: position)
        applyZoomFactor()
    }

    /// 입력을 갈아끼우면 연결이 새로 생기므로 그때마다 다시 잡는다. 세션 큐에서만 호출한다.
    private func configureConnections(position: CameraPosition) {
        // 프리뷰 레이어 없이 직접 프레임을 다루므로 세로 회전도 직접 지정한다 (앱은 세로 고정)
        let previewAngle: CGFloat = isSensorMountedPortrait ? 0 : 90
        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(previewAngle) {
            connection.videoRotationAngle = previewAngle
        }
        // photoOutput은 센서가 세로 장착이어도 스스로 이전 세대 방향(가로)으로 보정해 내보낸다
        if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        // 전면은 프리뷰도 촬영본도 거울상 (#122) — 찍는 사람은 거울을 보듯 잡고,
        // 방에 올라가는 사진도 그때 본 그대로여야 한다. 자동 판단에 맡기면 프리뷰만 뒤집힌다.
        for connection in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)] {
            guard let connection, connection.isVideoMirroringSupported else { continue }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }
    }

    /// 센서가 세로로 장착됐는지 — iPhone 17 계열 전면 카메라가 여기 해당한다.
    /// 이 플래그는 "이전 세대와 센서 방향이 다른 구성"에서만 참이라 기종 하드코딩 없이 판별에 쓸 수 있다.
    private var isSensorMountedPortrait: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return photoOutput.isCameraSensorOrientationCompensationSupported
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(
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

    public func photoOutput(
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

public enum CameraSessionError: LocalizedError {
    case noImageData

    public var errorDescription: String? {
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
