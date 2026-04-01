import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingChangeName = false
    @State private var showingDeleteAccount = false
    @State private var newDisplayName = ""
    @State private var errorMessage: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Avatar picker
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        if let avatarUrl = appState.currentUser?.avatarUrl,
                           let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                avatarPlaceholder
                            }
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                        } else {
                            avatarPlaceholder
                        }

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 28, height: 28)
                                if isUploadingAvatar {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.black)
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .disabled(isUploadingAvatar)
                    }

                    Text(appState.currentUser?.displayName ?? "")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(.top, 24)
                .padding(.bottom, 24)

                VStack(spacing: 12) {
                    Button {
                        newDisplayName = appState.currentUser?.displayName ?? ""
                        showingChangeName = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("change display name")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(12)
                    }

                    Button {
                        appState.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("sign out")
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.bottom, 8)
                }

                Button {
                    showingDeleteAccount = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("delete account")
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            uploadAvatar(item: newItem)
        }
        .alert("change display name", isPresented: $showingChangeName) {
            TextField("display name", text: $newDisplayName)
            Button("save") { updateDisplayName() }
            Button("cancel", role: .cancel) {}
        }
        .alert("delete account", isPresented: $showingDeleteAccount) {
            Button("delete", role: .destructive) { deleteAccount() }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this will permanently delete your account and all your data. this cannot be undone.")
        }
        .preferredColorScheme(.dark)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 88, height: 88)
            .overlay(
                Text(appState.currentUser?.displayName.prefix(1) ?? "?")
                    .font(.title)
                    .foregroundColor(.white)
            )
    }

    private func uploadAvatar(item: PhotosPickerItem) {
        isUploadingAvatar = true
        Task {
            do {
                print("=== loading image data...")
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let jpegData = image.jpegData(compressionQuality: 0.8) else {
                    print("=== failed to load image data")
                    isUploadingAvatar = false
                    return
                }
                print("=== image loaded, size:", jpegData.count)

                print("=== getting upload URL...")
                let (uploadUrl, key) = try await APIClient.shared.getAvatarUploadURL()
                print("=== got upload URL, key:", key)

                guard let url = URL(string: uploadUrl) else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                let (_, uploadResponse) = try await URLSession.shared.upload(for: request, from: jpegData)
                print("=== S3 upload status:", (uploadResponse as? HTTPURLResponse)?.statusCode ?? -1)

                let avatarUrl = "https://\(Constants.s3BucketName).s3.\(Constants.awsRegion).amazonaws.com/\(key)?t=\(Int(Date().timeIntervalSince1970))"
                
                let user = try await APIClient.shared.updateProfile(displayName: appState.currentUser?.displayName ?? "", avatarUrl: avatarUrl)
                print("=== profile updated!")
                print("=== new avatar URL:", appState.currentUser?.avatarUrl ?? "nil")
                await MainActor.run {
                    appState.currentUser = user
                    isUploadingAvatar = false
                }
            } catch {
                print("=== avatar upload error:", error)
                await MainActor.run {
                    errorMessage = "Failed to upload photo"
                    isUploadingAvatar = false
                }
            }
        }
    }
    private func updateDisplayName() {
        guard !newDisplayName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            do {
                let user = try await APIClient.shared.updateProfile(displayName: newDisplayName)
                await MainActor.run { appState.currentUser = user }
            } catch {
                errorMessage = "couldn't update name, try again"
            }
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await APIClient.shared.deleteAccount()
                await MainActor.run { appState.signOut() }
            } catch {
                errorMessage = "couldn't delete account, try again"
            }
        }
    }
}
