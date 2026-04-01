import SwiftUI

struct PhotoDetailView: View {
    let photo: Photo
    let groupName: String
    @Environment(\.dismiss) var dismiss
    @State private var isSaved = false
    @State private var isSaving = false
    @State private var showSavedToast = false

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

                    if !photo.locked {
                        Button {
                            sharePhoto()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
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

                if !photo.locked {
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

                        Button {
                            saveToLibrary()
                        } label: {
                            HStack(spacing: 6) {
                                if isSaving {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.black)
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }

            if showSavedToast {
                VStack {
                    Spacer()
                    Text("saved to library!")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                        .padding(.bottom, 80)
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await checkIfSaved()
        }
    }

    private func checkIfSaved() async {
        do {
            let library = try await APIClient.shared.getLibrary()
            await MainActor.run {
                isSaved = library.contains(where: { $0.id == photo.id })
                print("=== checkIfSaved: isSaved =", isSaved, "for photo:", photo.id)
            }
        } catch {
            print("=== checkIfSaved error:", error)
        }
    }

    private func saveToLibrary() {
        print("=== save tapped, photo id:", photo.id, "locked:", photo.locked)
        isSaving = true
        Task {
            do {
                try await APIClient.shared.savePhoto(photoId: photo.id)
                print("=== saved!")
                await MainActor.run {
                    isSaved = true
                    isSaving = false
                    withAnimation { showSavedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSavedToast = false }
                    }
                }
            } catch {
                print("=== save error:", error)
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func sharePhoto() {
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
