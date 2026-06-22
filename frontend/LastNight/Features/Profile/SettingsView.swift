import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingChangeName = false
    @State private var showingChangeBio = false
    @State private var newDisplayName = ""
    @State private var newBio = ""
    @State private var errorMessage: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var cropImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
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
                        newBio = appState.currentUser?.bio ?? ""
                        showingChangeBio = true
                    } label: {
                        HStack(alignment: .top) {
                            Image(systemName: "text.quote")
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("edit bio")
                                if let bio = appState.currentUser?.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                } else {
                                    Text("add a bio")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.6))
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(12)
                    }

                    NavigationLink {
                        AdvancedSettingsView()
                            .environmentObject(appState)
                    } label: {
                        HStack {
                            Image(systemName: "ellipsis.circle")
                            Text("more")
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
                    NotificationToggleRow()
                }
                .padding(.horizontal, 24)

                // Sign out, separated from edit actions to avoid mis-taps.
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
                .padding(.horizontal, 24)
                .padding(.top, 28)

                Spacer()

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.bottom, 8)
                }
            }
        }
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            loadImageForCrop(item: newItem)
        }
        .fullScreenCover(item: Binding(
            get: { cropImage.map { CroppableImage(image: $0) } },
            set: { if $0 == nil { cropImage = nil } }
        )) { croppable in
            AvatarCropView(
                image: croppable.image,
                onCancel: {
                    cropImage = nil
                    selectedPhoto = nil
                },
                onCrop: { cropped in
                    cropImage = nil
                    selectedPhoto = nil
                    uploadAvatar(image: cropped)
                }
            )
        }
        .alert("change display name", isPresented: $showingChangeName) {
            TextField("display name", text: $newDisplayName)
            Button("save") { updateDisplayName() }
            Button("cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingChangeBio) {
            EditBioSheet(bio: $newBio, onSave: { updateBio() })
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

    private func loadImageForCrop(item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    cropImage = image
                }
            }
        }
    }

    private func uploadAvatar(image: UIImage) {
        isUploadingAvatar = true
        Task {
            do {
                guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
                    isUploadingAvatar = false
                    return
                }

                let (uploadUrl, key) = try await APIClient.shared.getAvatarUploadURL()

                guard let url = URL(string: uploadUrl) else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                _ = try await URLSession.shared.upload(for: request, from: jpegData)

                let avatarUrl = "https://\(Constants.s3BucketName).s3.\(Constants.awsRegion).amazonaws.com/\(key)?t=\(Int(Date().timeIntervalSince1970))"

                let user = try await APIClient.shared.updateProfile(displayName: appState.currentUser?.displayName ?? "", avatarUrl: avatarUrl)
                await MainActor.run {
                    appState.currentUser = user
                    isUploadingAvatar = false
                }
            } catch {
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

    private func updateBio() {
        Task {
            do {
                let user = try await APIClient.shared.updateProfile(
                    displayName: appState.currentUser?.displayName ?? "",
                    bio: newBio
                )
                await MainActor.run {
                    appState.currentUser = user
                    showingChangeBio = false
                }
            } catch {
                errorMessage = "couldn't update bio, try again"
            }
        }
    }
}

// Wrapper so a UIImage can drive .fullScreenCover(item:)
private struct CroppableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct NotificationToggleRow: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var systemAuthorized = true
    @State private var showSettingsAlert = false

    var body: some View {
        Button {
            handleTap()
        } label: {
            HStack {
                Image(systemName: notificationsEnabled && systemAuthorized ? "bell.fill" : "bell.slash")
                Text("notifications")
                Spacer()
                // Visual toggle (non-interactive; the row handles taps)
                Toggle("", isOn: Binding(
                    get: { notificationsEnabled && systemAuthorized },
                    set: { _ in handleTap() }
                ))
                .labelsHidden()
                .tint(.white)
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.white.opacity(0.07))
            .cornerRadius(12)
        }
        .task { await refreshAuthStatus() }
        .alert("notifications are off", isPresented: $showSettingsAlert) {
            Button("open settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("turn on notifications for Last Night in your device settings to get alerts.")
        }
    }

    private func handleTap() {
        Task {
            await refreshAuthStatus()

            // If iOS permission is denied, we can't enable in-app — send to Settings.
            if !systemAuthorized {
                showSettingsAlert = true
                return
            }

            if notificationsEnabled {
                // Turn OFF — remove this device's token
                notificationsEnabled = false
                if let token = AppState.latestFCMToken ?? (try? await Messaging.messaging().token()) {
                    try? await APIClient.shared.unregisterDeviceToken(token)
                }
            } else {
                // Turn ON — re-register the token
                notificationsEnabled = true
                if let token = AppState.latestFCMToken ?? (try? await Messaging.messaging().token()) {
                    AppState.latestFCMToken = token
                    try? await APIClient.shared.registerDeviceToken(token, environment: "fcm")
                }
            }
        }
    }

    private func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingDeleteAccount = false
    @State private var showingPrivacyPolicy = false
    @State private var showingHowItWorks = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Button {
                        showingHowItWorks = true
                    } label: {
                        HStack {
                            Image(systemName: "questionmark")
                            Text(" how it works")
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
                        showingPrivacyPolicy = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("terms & privacy")
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
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

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
        .navigationTitle("more")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingHowItWorks) {
            OnboardingView {
                showingHowItWorks = false
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            LegalSheetView(initialPage: .terms)
        }
        .alert("delete account", isPresented: $showingDeleteAccount) {
            Button("delete", role: .destructive) { deleteAccount() }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this will permanently delete your account and all your data. this cannot be undone.")
        }
        .preferredColorScheme(.dark)
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

struct EditBioSheet: View {
    @Binding var bio: String
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    Text("bio")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top, 16)

                    TextEditor(text: $bio)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(12)
                        .frame(height: 140)
                        .padding(.horizontal)

                    Text("\(bio.count)/150")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("edit bio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { onSave() }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: bio) { _, newValue in
                if newValue.count > 150 {
                    bio = String(newValue.prefix(150))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
