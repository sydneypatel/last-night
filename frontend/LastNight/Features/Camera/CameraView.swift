import SwiftUI
import AVFoundation
import MediaPlayer
import Combine
import ActivityKit

class OrientationObserver: ObservableObject {
    @Published var angle: Angle = .degrees(0)
    private var observer: NSObjectProtocol?

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            switch UIDevice.current.orientation {
            case .landscapeLeft:  self?.angle = .degrees(90)
            case .landscapeRight: self?.angle = .degrees(-90)
            case .portraitUpsideDown: self?.angle = .degrees(180)
            default: self?.angle = .degrees(0)
            }
        }
    }

    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
    
}

struct CameraView: View {
    let groupId: String
    var onPhotoTaken: (Photo?) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var orientationObserver = OrientationObserver()
    
    private var flashIconName: String {
        switch viewModel.flashMode {
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        default: return "bolt.slash.fill"
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()
                .onTapGesture(count: 2) {
                    viewModel.flipCamera()
                }

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
                    .rotationEffect(orientationObserver.angle)
                    .animation(.easeInOut(duration: 0.3), value: orientationObserver.angle)

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
                    .rotationEffect(orientationObserver.angle)
                    .animation(.easeInOut(duration: 0.3), value: orientationObserver.angle)

                    Button {
                        print("🔦 flash button tapped")
                        viewModel.cycleFlash()
                    } label: {
                        Image(systemName: flashIconName)
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .rotationEffect(orientationObserver.angle)
                    .animation(.easeInOut(duration: 0.3), value: orientationObserver.angle)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .overlay(
                    Text("LAST NIGHT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .allowsHitTesting(false)
                )
                
                Spacer()

                if !viewModel.isFrontCamera {
                    Button {
                        print("📐 0.5x button tapped")
                        viewModel.toggleUltraWide()
                    } label: {
                        Text(viewModel.isUltraWide ? "1x" : ".5x")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .padding(.bottom, 12)
                }
                
                ZStack {
                    if viewModel.isRecordingVideo {
                        Circle()
                            .trim(from: 0, to: viewModel.recordingProgress)
                            .stroke(Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 81, height: 80)
                    }
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 76, height: 76)
                    Circle()
                        .fill(viewModel.isRecordingVideo ? Color.red : Color.white)
                        .frame(width: viewModel.isRecordingVideo ? 32 : 62, height: viewModel.isRecordingVideo ? 32 : 62)
                        .cornerRadius(viewModel.isRecordingVideo ? 8 : 31)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecordingVideo)
                }
                .gesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .onEnded { _ in
                            guard !viewModel.isFrontCamera else { return }
                            viewModel.startRecording()
                        }
                        .simultaneously(with: DragGesture(minimumDistance: 0)
                            .onEnded { _ in
                                if viewModel.isRecordingVideo {
                                    viewModel.stopRecording()
                                } else if !viewModel.isCapturing {
                                    viewModel.capturePhoto()
                                }
                            }
                        )
                )
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
        .onChange(of: viewModel.capturedImage) { _, image in
            guard let image else { return }
            uploadPhoto(image: image)
        }
        .onChange(of: viewModel.capturedVideoURL) { _, url in
            guard let url else { return }
            uploadVideo(url: url)
        }
        .onAppear { setupVolumeButtons() }
        .onDisappear {
            viewModel.stopSession()
            teardownVolumeButtons()
        }
    }

    private func setupVolumeButtons() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil,
            queue: .main
        ) { _ in
            guard !viewModel.isCapturing else { return }
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

    private func uploadPhoto(image: UIImage) {
        viewModel.stopSession()
        dismiss()

        Task {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.85) else { return }
                let urlResponse = try await APIClient.shared.getUploadURL(groupId: groupId)
                try await uploadToS3(data: imageData, url: urlResponse.uploadUrl)
                let photo = try await APIClient.shared.confirmUpload(
                    groupId: groupId,
                    s3Key: urlResponse.s3Key,
                    thumbnailKey: urlResponse.s3Key
                )
                await MainActor.run {
                    onPhotoTaken(photo)
                }
                await syncLiveActivity()
            } catch {
                print("Background upload failed:", error)
            }
        }
    }
    
    private func uploadVideo(url: URL) {
        viewModel.stopSession()
        dismiss()

        Task {
            do {
                let videoData = try Data(contentsOf: url)
                let thumbnailImage = try await extractFirstFrame(from: url)
                guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7) else { return }

                let duration = try await videoDuration(url: url)

                let videoUploadResponse = try await APIClient.shared.getUploadURL(groupId: groupId, contentType: "video/quicktime")
                try await uploadToS3(data: videoData, url: videoUploadResponse.uploadUrl, contentType: "video/quicktime")

                let thumbUploadResponse = try await APIClient.shared.getUploadURL(groupId: groupId, contentType: "image/jpeg")
                try await uploadToS3(data: thumbnailData, url: thumbUploadResponse.uploadUrl, contentType: "image/jpeg")

                let photo = try await APIClient.shared.confirmUpload(
                    groupId: groupId,
                    s3Key: videoUploadResponse.s3Key,
                    thumbnailKey: thumbUploadResponse.thumbnailKey,
                    mediaType: "video",
                    durationSeconds: duration
                )
                await MainActor.run {
                    onPhotoTaken(photo)
                }
                await syncLiveActivity()

                try? FileManager.default.removeItem(at: url)
            } catch {
                print("Video upload failed:", error)
            }
        }
    }

    private func extractFirstFrame(from url: URL) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let cgImage = try await generator.image(at: .zero).image
        return UIImage(cgImage: cgImage)
    }

    private func videoDuration(url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    private func syncLiveActivity() async {
        do {
            let (group, _) = try await APIClient.shared.getGroup(id: groupId)
            let photos = try await APIClient.shared.getPhotos(groupId: groupId)

            await MainActor.run {
                let alreadyRunning = Activity<GroupActivityAttributes>.activities.contains {
                    $0.attributes.groupId == groupId
                }
                if alreadyRunning {
                    GroupLiveActivityManager.updatePhotoCount(groupId: groupId, newCount: photos.count)
                } else if let unlockAt = group.unlockAt {
                    GroupLiveActivityManager.start(
                        groupId: groupId,
                        groupName: group.name,
                        unlockDate: unlockAt,
                        photoCount: photos.count
                    )
                }
            }
        } catch {
            print("Failed to sync live activity:", error)
        }
    }

    private func uploadToS3(data: Data, url: String, contentType: String = "image/jpeg") async throws {
        guard let uploadURL = URL(string: url) else { throw APIError.badRequest("Invalid URL") }
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.serverError("S3 upload failed")
        }
    }
}
