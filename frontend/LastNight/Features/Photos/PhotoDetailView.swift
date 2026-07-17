import SwiftUI
import Photos
import AVKit

struct PhotoDetailView: View {
    let photos: [Photo]
    let startIndex: Int
    let groupName: String
    var onPhotoDeleted: ((String) -> Void)?
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int
    @State private var isSaving = false
    @State private var isSavingToCamera = false
    @State private var showSavedToast = false
    @State private var savedPhotoIds: Set<String> = []
    @State private var showingDeleteConfirm = false
    @State private var isDeleting = false
    @State private var localPhotos: [Photo]
    @State private var showingReportSheet = false
    @State private var showingReportConfirm = false
    @State private var showingReportError = false

    init(photos: [Photo], startIndex: Int, groupName: String, onPhotoDeleted: ((String) -> Void)? = nil) {
        self.photos = photos
        self.startIndex = startIndex
        self.groupName = groupName
        self.onPhotoDeleted = onPhotoDeleted
        _currentIndex = State(initialValue: startIndex)
        _localPhotos = State(initialValue: photos)
    }

    var currentPhoto: Photo { localPhotos[currentIndex] }

    var isOwnPhoto: Bool {
        currentPhoto.userId == appState.currentUser?.id
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(localPhotos.enumerated()), id: \.offset) { index, photo in
                    PhotoPageView(
                        photo: photo,
                        groupName: groupName,
                        isSaving: isSaving,
                        isSavingToCamera: isSavingToCamera,
                        isSaved: savedPhotoIds.contains(photo.id),
                        onSaveToLibrary: { saveToLibrary(photo: photo) },
                        onSaveToCamera: { saveToCameraRoll(photo: photo) },
                        onShare: { sharePhoto(photo: photo) }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("\(currentIndex + 1) / \(localPhotos.count)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    if isOwnPhoto {
                        Button {
                            showingDeleteConfirm = true
                        } label: {
                            Image(systemName: isDeleting ? "trash" : "trash")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .disabled(isDeleting)
                    } else {
                        Button {
                            showingReportSheet = true
                        } label: {
                            Image(systemName: "flag")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()
            }

            if showSavedToast {
                VStack {
                    Spacer()
                    Text("saved!")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                        .padding(.bottom, 140)
                }
                .transition(.opacity)
            }

            if isDeleting {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
        .preferredColorScheme(.dark)
        .alert("delete photo?", isPresented: $showingDeleteConfirm) {
            Button("delete", role: .destructive) { deletePhoto() }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this will permanently remove the photo from the group.")
        }
        .task {
            await checkSavedPhotos()
        }
        .confirmationDialog("report photo", isPresented: $showingReportSheet, titleVisibility: .visible) {
            Button("nudity / sexual content") { reportPhoto(reason: "nudity / sexual content") }
            Button("violence / graphic content") { reportPhoto(reason: "violence / graphic content") }
            Button("harassment / bullying") { reportPhoto(reason: "harassment / bullying") }
            Button("hate speech") { reportPhoto(reason: "hate speech") }
            Button("dangerous or illegal activity") { reportPhoto(reason: "dangerous or illegal activity") }
            Button("other") { reportPhoto(reason: "other") }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("why are you reporting this photo?")
        }
        .alert("photo reported", isPresented: $showingReportConfirm) {
            Button("ok", role: .cancel) {}
        } message: {
            Text("thanks for helping keep last night safe. our team will review this photo.")
        }
        .alert("couldn't report", isPresented: $showingReportError) {
            Button("ok", role: .cancel) {}
        } message: {
            Text("something went wrong. please try again.")
        }
    }
    
    private func deletePhoto() {
        let photo = currentPhoto
        isDeleting = true
        Task {
            do {
                try await APIClient.shared.deletePhoto(photoId: photo.id)
                await MainActor.run {
                    isDeleting = false
                    onPhotoDeleted?(photo.id)

                    if localPhotos.count == 1 {
                        // Last photo — dismiss
                        dismiss()
                    } else {
                        // Remove from local array, adjust index
                        let newIndex = currentIndex >= localPhotos.count - 1
                            ? currentIndex - 1
                            : currentIndex
                        localPhotos.removeAll { $0.id == photo.id }
                        currentIndex = newIndex
                    }
                }
            } catch {
                print("Delete photo error:", error)
                await MainActor.run { isDeleting = false }
            }
        }
    }
    
    private func reportPhoto(reason: String) {
        let photo = currentPhoto
        Task {
            do {
                try await APIClient.shared.reportPhoto(photoId: photo.id, reason: reason)
                await MainActor.run {
                    showingReportConfirm = true
                }
            } catch {
                print("Report error:", error)
                await MainActor.run {
                    showingReportError = true  // an alert: "couldn't report, try again"
                }
            }
        }
    }

    private func checkSavedPhotos() async {
        do {
            let library = try await APIClient.shared.getLibrary()
            await MainActor.run {
                savedPhotoIds = Set(library.map { $0.id })
            }
        } catch {
            print("Error checking library:", error)
        }
    }

    private func saveToLibrary(photo: Photo) {
        guard !savedPhotoIds.contains(photo.id) else { return }
        isSaving = true
        Task {
            do {
                try await APIClient.shared.savePhoto(photoId: photo.id)
                await MainActor.run {
                    savedPhotoIds.insert(photo.id)
                    isSaving = false
                    withAnimation { showSavedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSavedToast = false }
                    }
                }
            } catch {
                print("Save to library error:", error)
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func saveToCameraRoll(photo: Photo) {
        isSavingToCamera = true
        guard let url = photo.url, let imageURL = URL(string: url) else {
            isSavingToCamera = false
            return
        }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                guard let image = UIImage(data: data) else {
                    await MainActor.run { isSavingToCamera = false }
                    return
                }
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized || status == .limited else {
                    await MainActor.run { isSavingToCamera = false }
                    return
                }
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                await MainActor.run {
                    isSavingToCamera = false
                    withAnimation { showSavedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSavedToast = false }
                    }
                }
            } catch {
                print("Save to camera roll error:", error)
                await MainActor.run { isSavingToCamera = false }
            }
        }
    }

    private func sharePhoto(photo: Photo) {
        guard let url = photo.url, let imageURL = URL(string: url) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                        UIApplication.shared.connectedScenes
                            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                            .first?
                            .present(av, animated: true)
                    }
                }
            } catch {
                print("Share error:", error)
            }
        }
    }
}

struct PhotoPageView: View {
    let photo: Photo
    let groupName: String
    let isSaving: Bool
    let isSavingToCamera: Bool
    let isSaved: Bool
    var onSaveToLibrary: () -> Void
    var onSaveToCamera: () -> Void
    var onShare: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if photo.mediaType == .video, let url = photo.url, let videoURL = URL(string: url) {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let url = photo.url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } placeholder: {
                    ProgressView().tint(.white)
                }
            }

            if !photo.locked {
                VStack {
                    Spacer()
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(photo.username ?? "")")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                Text(groupName)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                if let capturedAt = photo.capturedAt {
                                    Text(capturedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }

                            Spacer()

                            HStack(spacing: 10) {
                                Button {
                                    onSaveToLibrary()
                                } label: {
                                    HStack(spacing: 6) {
                                        if isSaving {
                                            ProgressView().scaleEffect(0.7).tint(.black)
                                        } else {
                                            Image(systemName: isSaved ? "heart.fill" : "heart")
                                                .font(.subheadline)
                                        }
                                        Text(isSaved ? "saved" : "save")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(isSaved ? .red : .black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                }
                                .disabled(isSaving || isSaved)

                                Button {
                                    onSaveToCamera()
                                } label: {
                                    HStack(spacing: 6) {
                                        if isSavingToCamera {
                                            ProgressView().scaleEffect(0.7).tint(.black)
                                        } else {
                                            Image(systemName: "square.and.arrow.down")
                                                .font(.subheadline)
                                        }
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                }
                                .disabled(isSavingToCamera)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
}
