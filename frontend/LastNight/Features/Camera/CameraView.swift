import SwiftUI
import AVFoundation

struct CameraView: View {
    let groupId: String
    var onPhotoTaken: (Photo) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CameraViewModel()
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showPreview = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let preview = viewModel.capturedImage, showPreview {
                PhotoPreviewView(
                    image: preview,
                    isUploading: isUploading,
                    uploadError: uploadError,
                    onRetake: {
                        viewModel.capturedImage = nil
                        showPreview = false
                        uploadError = nil
                    },
                    onUse: {
                        uploadPhoto(image: preview)
                    }
                )
            } else {
                CameraPreview(session: viewModel.session)
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        CornerBracket().frame(width: 30, height: 30)
                        Spacer()
                        CornerBracket().rotationEffect(.degrees(90)).frame(width: 30, height: 30)
                    }
                    Spacer()
                    HStack {
                        CornerBracket().rotationEffect(.degrees(270)).frame(width: 30, height: 30)
                        Spacer()
                        CornerBracket().rotationEffect(.degrees(180)).frame(width: 30, height: 30)
                    }
                }
                .padding(32)
                .opacity(0.5)

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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showPreview = true
                        }
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
        .onDisappear {
            viewModel.stopSession()
        }
    }

    private func uploadPhoto(image: UIImage) {
        isUploading = true
        uploadError = nil

        Task {
            do {
                let filtered = PhotoFilter.applyDigiCamFilter(to: image)

                guard let imageData = PhotoFilter.toJPEGData(filtered) else {
                    await MainActor.run { uploadError = "Failed to process photo" }
                    isUploading = false
                    return
                }

                // Get one presigned URL for the full image
                let urlResponse = try await APIClient.shared.getUploadURL(groupId: groupId)
                try await uploadToS3(data: imageData, url: urlResponse.uploadUrl)

                // Confirm with backend — use same key for thumbnail for now
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

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
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
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.black)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }
                    .disabled(isUploading)

                    Button {
                        onUse()
                    } label: {
                        if isUploading {
                            ProgressView().tint(.black)
                        } else {
                            Text("use photo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(20)
                    .disabled(isUploading)
                }
                .padding(.bottom, 48)
            }
        }
    }
}

struct CornerBracket: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            context.stroke(path, with: .color(.white), lineWidth: 2)
        }
    }
}
