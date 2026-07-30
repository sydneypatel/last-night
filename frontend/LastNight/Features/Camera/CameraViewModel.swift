import AVFoundation
import UIKit
import Combine

@MainActor
class CameraViewModel: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var capturedVideoURL: URL?
    @Published var isCapturing = false
    @Published var isRecordingVideo = false
    @Published var recordingProgress: Double = 0 // 0...1 over 10 seconds
    @Published var error: String?
    @Published var isFrontCamera = false
    @Published var zoomFactor: CGFloat = 1.0
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isUltraWide = false

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    private let maxRecordingDuration: TimeInterval = 10.0

    override init() {
        super.init()
        Task { await setupSession() }
    }

    func setupSession() async {
        guard await checkPermission() else {
            error = "Camera access denied. Go to Settings to enable."
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = backCameraDevice(),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = "Could not access camera."
            return
        }
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        currentInput = input
        session.commitConfiguration()
        print("📷 device type:", currentInput?.device.deviceType.rawValue ?? "none")

        Task.detached { [weak self] in
            self?.session.startRunning()
        }
    }

    func checkPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    // MARK: - Device selection

    private func backCameraDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    // MARK: - Flip

    func flipCamera() {
        let position: AVCaptureDevice.Position = isFrontCamera ? .back : .front
        let device: AVCaptureDevice?
        if position == .back {
            device = backCameraDevice()
        } else {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        guard let device, let newInput = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()
        if let current = currentInput { session.removeInput(current) }
        if session.canAddInput(newInput) { session.addInput(newInput) }

        // Video recording is back-camera only (front camera has a known distortion
        // issue when movieOutput is attached — see earlier fix). Keep movieOutput
        // attached persistently on back camera so startRecording() is instant with
        // no mid-press reconfiguration race; detach it when going to front.
        if position == .front {
            session.removeOutput(movieOutput)
        } else if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        currentInput = newInput
        session.commitConfiguration()

        isFrontCamera.toggle()
        zoomFactor = 1.0
        isUltraWide = false
        setZoom(1.0)
    }

    // MARK: - Flash

    func cycleFlash() {
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        default: flashMode = .off
        }
        print("🔦 flashMode is now:", flashMode.rawValue)
    }

    // MARK: - Zoom / 0.5x ultra-wide

    func toggleUltraWide() {
        guard !isFrontCamera else { return }
        let targetType: AVCaptureDevice.DeviceType = isUltraWide ? .builtInWideAngleCamera : .builtInUltraWideCamera
        guard let device = AVCaptureDevice.default(targetType, for: .video, position: .back),
              let newInput = try? AVCaptureDeviceInput(device: device) else {
            print("📐 could not get device for", targetType)
            return
        }
        session.beginConfiguration()
        if let current = currentInput { session.removeInput(current) }
        if session.canAddInput(newInput) { session.addInput(newInput) }
        currentInput = newInput
        session.commitConfiguration()
        isUltraWide.toggle()
        zoomFactor = 1.0
        setZoom(1.0)
        print("📐 isUltraWide is now:", isUltraWide)
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = currentInput?.device else { return }
        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = min(device.maxAvailableVideoZoomFactor, 5.0)
        let clamped = max(minZoom, min(factor, maxZoom))
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {
            print("Zoom error:", error)
        }
    }

    // MARK: - Photo capture

    func capturePhoto() {
        isCapturing = true
        if let connection = photoOutput.connection(with: .video) {
            let angle = captureRotationAngle()
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
        let settings = AVCapturePhotoSettings()
        if currentInput?.device.hasFlash == true {
            settings.flashMode = flashMode
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Video capture

    func startRecording() {
        print("🟢 startRecording() called", Date())
        guard !isRecordingVideo else { return }
        guard !isFrontCamera else { return }

        if let connection = movieOutput.connection(with: .video) {
            let angle = captureRotationAngle()
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            connection.isVideoMirrored = isFrontCamera
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecordingVideo = true
        recordingStartTime = Date()
        recordingProgress = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            Task { @MainActor in
                self.recordingProgress = min(elapsed / self.maxRecordingDuration, 1.0)
                if elapsed >= self.maxRecordingDuration {
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        guard isRecordingVideo else { return }
        movieOutput.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func captureRotationAngle() -> CGFloat {
        switch UIDevice.current.orientation {
        case .landscapeLeft:  return 0
        case .landscapeRight: return 180
        case .portraitUpsideDown: return 270
        default: return 90
        }
    }

    func stopSession() {
        Task.detached { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: - Image processing

    private func mirrorHorizontally(_ image: UIImage) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: image.size.width, y: 0)
        context.scaleBy(x: -1, y: 1)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let mirrored = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return mirrored
    }

    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return normalized
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        Task { @MainActor in
            var processed = self.normalizeOrientation(image)
            if self.isFrontCamera {
                processed = self.mirrorHorizontally(processed)
            }
            self.capturedImage = processed
            self.isCapturing = false
        }
    }
}

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.isRecordingVideo = false
            self.recordingProgress = 0

            if let error {
                print("Video recording error:", error)
                return
            }
            self.capturedVideoURL = outputFileURL
        }
    }
}
