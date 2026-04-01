import SwiftUI
import Photos

struct PhotoDetailView: View {
    let photos: [Photo]
    let startIndex: Int
    let groupName: String
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int
    @State private var isSaving = false
    @State private var isSavingToCamera = false
    @State private var showSavedToast = false
    @State private var savedPhotoIds: Set<String> = []

    init(photos: [Photo], startIndex: Int, groupName: String) {
        self.photos = photos
        self.startIndex = startIndex
        self.groupName = groupName
        _currentIndex = State(initialValue: startIndex)
    }

    var currentPhoto: Photo { photos[currentIndex] }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
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

                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Color.clear.frame(width: 44, height: 44)
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
        }
        .preferredColorScheme(.dark)
        .task {
            await checkSavedPhotos()
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

            if let url = photo.url, let imageURL = URL(string: url) {
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
                                // Save to in-app library (heart pill)
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

                                // Save to camera roll (download pill)
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
