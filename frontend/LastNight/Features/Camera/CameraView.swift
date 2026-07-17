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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: viewModel.session)
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
                    .rotationEffect(orientationObserver.angle)
                    .animation(.easeInOut(duration: 0.3), value: orientationObserver.angle)

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
                    .rotationEffect(orientationObserver.angle)
                    .animation(.easeInOut(duration: 0.3), value: orientationObserver.angle)
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
        .onChange(of: viewModel.capturedImage) { _, image in
            guard let image else { return }
            uploadPhoto(image: image)
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
