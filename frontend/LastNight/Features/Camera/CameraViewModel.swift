import AVFoundation
import UIKit
import Combine

@MainActor
class CameraViewModel: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isCapturing = false
    @Published var error: String?
    @Published var isFrontCamera = false
    @Published var zoomFactor: CGFloat = 1.0

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?

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
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = "Could not access camera."
            return
        }
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        currentInput = input
        session.commitConfiguration()

        Task.detached { [weak self] in
            guard let self else { return }
            self.session.startRunning()
            await MainActor.run {
                if let connection = self.photoOutput.connection(with: .video),
                   connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
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

    func flipCamera() {
        let position: AVCaptureDevice.Position = isFrontCamera ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        if let current = currentInput { session.removeInput(current) }
        if session.canAddInput(newInput) { session.addInput(newInput) }
        currentInput = newInput
        session.commitConfiguration()
        isFrontCamera.toggle()
        zoomFactor = 1.0
        setZoom(1.0)
    }

    func capturePhoto() {
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func stopSession() {
        Task.detached { [weak self] in
            self?.session.stopRunning()
        }
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = currentInput?.device else { return }
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
        let clamped = max(1.0, min(factor, maxZoom))
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {
            print("Zoom error:", error)
        }
    }

    // Mirror image horizontally (for front camera)
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
