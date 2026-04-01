//
//  CameraViewModel.swift
//  LastNight
//
//  Created by Sydney Patel on 3/31/26.
//

import AVFoundation
import UIKit
import Combine

@MainActor
class CameraViewModel: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isCapturing = false
    @Published var error: String?
    @Published var isFrontCamera = false

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
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        Task { @MainActor in
            self.capturedImage = image
            self.isCapturing = false
        }
    }
}
