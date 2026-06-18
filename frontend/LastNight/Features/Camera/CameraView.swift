import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

struct CameraView: View {
    let groupId: String
    var onPhotoTaken: (Photo) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CameraViewModel()
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let preview = viewModel.capturedImage {
                PhotoPreviewView(
                    image: preview,
                    isUploading: isUploading,
                    uploadError: uploadError,
                    onRetake: {
                        viewModel.capturedImage = nil
                        uploadError = nil
                        Task.detached { [weak viewModel] in
                            viewModel?.session.startRunning()
                        }
                    },
                    onUse: {
                        uploadPhoto(image: preview)
                    }
                )
            } else {
                CameraPreview(session: viewModel.session)
                    .ignoresSafeArea()
                .ignoresSafeArea()

                VStack {
                    HStack {
                        Button {
                            viewModel.stopSession()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Text("LAST NIGHT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Button {
                            viewModel.flipCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Spacer()

                    Button {
                        viewModel.capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 76, height: 76)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 62, height: 62)
                        }
                    }
                    .disabled(viewModel.isCapturing)
                    .padding(.bottom, 48)
                }

                if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
        .onAppear {
            setupVolumeButtons()
        }
        .onDisappear {
            viewModel.stopSession()
            teardownVolumeButtons()
        }
    }

    // MARK: - Volume button shutter
    private func setupVolumeButtons() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil,
            queue: .main
        ) { _ in
            guard viewModel.capturedImage == nil, !viewModel.isCapturing else { return }
            viewModel.capturePhoto()
        }
    }

    private func teardownVolumeButtons() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil
        )
    }

    // MARK: - Upload
    private func uploadPhoto(image: UIImage) {
        isUploading = true
        uploadError = nil

        Task {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.85) else {
                    await MainActor.run { uploadError = "Failed to process photo" }
                    isUploading = false
                    return
                }
                let urlResponse = try await APIClient.shared.getUploadURL(groupId: groupId)
                try await uploadToS3(data: imageData, url: urlResponse.uploadUrl)

                let photo = try await APIClient.shared.confirmUpload(
                    groupId: groupId,
                    s3Key: urlResponse.s3Key,
                    thumbnailKey: urlResponse.s3Key
                )

                await MainActor.run {
                    onPhotoTaken(photo)
                    viewModel.stopSession()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    uploadError = "Upload failed — try again"
                    isUploading = false
                }
            }
        }
    }

    private func uploadToS3(data: Data, url: String) async throws {
        guard let uploadURL = URL(string: url) else { throw APIError.badRequest("Invalid URL") }
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.serverError("S3 upload failed")
        }
    }
}

struct PhotoPreviewView: View {
    let image: UIImage
    let isUploading: Bool
    let uploadError: String?
    var onRetake: () -> Void
    var onUse: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            VStack {
                Spacer()

                if let error = uploadError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.bottom, 8)
                }

                HStack(spacing: 16) {
                    Button {
                        onRetake()
                    } label: {
                        Text("retake")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 120, height: 44)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                    }
                    .disabled(isUploading)

                    Button {
                        onUse()
                    } label: {
                        ZStack {
                            if isUploading {
                                ProgressView().tint(.black)
                            } else {
                                Text("use photo")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(width: 120, height: 44)
                        .background(Color.white)
                        .cornerRadius(20)
                    }
                    .disabled(isUploading)
                }
                .padding(.bottom, 48)
            }
        }
    }
}
