import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var featuredSlots: [LNFeaturedSlot] = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
    @State private var myPhotos: [Photo] = []
    @State private var isLoading = true
    @State private var followerCount = 0
    @State private var followingCount = 0
    @State private var showingFollowList: FollowListMode?
    @State private var showingEditFeatured = false
    @State private var pickerSlot: LNFeaturedSlot?
    @State private var showingAvatarFullScreen = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 10) {
                            SwiftUI.Group {
                                if let avatarUrl = appState.currentUser?.avatarUrl,
                                   let url = URL(string: avatarUrl) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Circle().fill(Color.white.opacity(0.1))
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Text(appState.currentUser?.displayName.prefix(1) ?? "?")
                                                .font(.title)
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            .onTapGesture {
                                showingAvatarFullScreen = true
                            }

                            VStack(spacing: 4) {
                                Text(appState.currentUser?.displayName ?? "")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text("@\(appState.currentUser?.username ?? "")")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                if let bio = appState.currentUser?.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                        .padding(.top, 4)
                                }
                            }

                            HStack(spacing: 24) {
                                Button { showingFollowList = .followers } label: {
                                    VStack(spacing: 2) {
                                        Text("\(followerCount)")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        Text("followers")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Button { showingFollowList = .following } label: {
                                    VStack(spacing: 2) {
                                        Text("\(followingCount)")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        Text("following")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 24)

                        HStack {
                            Text("my favorites:")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Button {
                                showingEditFeatured = true
                            } label: {
                                Text("edit")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                        if isLoading {
                            ProgressView().tint(.white).padding(.top, 40)
                        } else {
                            FeaturedGridView(slots: featuredSlots, isOwner: true) { slot in
                                if slot.photo == nil {
                                    pickerSlot = slot
                                } else {
                                    showingEditFeatured = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                }
            }
            .task { await loadFeatured() }
            .onAppear { Task { await loadFeatured() } }
            .fullScreenCover(isPresented: $showingAvatarFullScreen) {
                AvatarFullScreenView(
                    avatarUrl: appState.currentUser?.avatarUrl,
                    fallbackInitial: String(appState.currentUser?.displayName.prefix(1) ?? "?")
                )
            }
            .sheet(isPresented: $showingEditFeatured, onDismiss: {
                Task { await loadFeatured() }
            }) {
                EditFeaturedView().environmentObject(appState)
            }
            .sheet(item: $pickerSlot, onDismiss: {
                Task { await loadFeatured() }
            }) { slot in
                PhotoPickerView(
                    slot: slot,
                    photos: myPhotos,
                    onSelect: { photoId in
                        Task { await setFeatured(position: slot.position, photoId: photoId) }
                    },
                    onClear: {
                        Task { await setFeatured(position: slot.position, photoId: nil) }
                    }
                )
            }
            .sheet(item: $showingFollowList) { mode in
                if let userId = appState.currentUser?.id, let username = appState.currentUser?.username {
                    FollowListView(userId: userId, username: username, mode: mode)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadFeatured() async {
        guard let username = appState.currentUser?.username else {
            isLoading = false
            return
        }
        do {
            async let photosTask = APIClient.shared.getMyPhotosForFeaturing()
            myPhotos = (try? await photosTask) ?? []

            let fetched = try await APIClient.shared.getFeaturedGrid(username: username)
            featuredSlots = (1...9).map { pos in
                fetched.first(where: { $0.position == pos }) ?? LNFeaturedSlot(position: pos, photo: nil)
            }

            let profile = try await APIClient.shared.getUserProfile(username: username)
            followerCount = profile.followerCount ?? 0
            followingCount = profile.followingCount ?? 0
        } catch {
            print("Error loading featured:", error)
        }
        isLoading = false
    }

    private func setFeatured(position: Int, photoId: String?) async {
        do {
            try await APIClient.shared.setFeaturedPhoto(position: position, photoId: photoId)
            var newFeaturedPhoto: FeaturedPhoto? = nil
            if let photoId, let photo = myPhotos.first(where: { $0.id == photoId }) {
                newFeaturedPhoto = FeaturedPhoto(
                    id: photo.id,
                    s3Key: photo.s3Key,
                    locked: photo.locked,
                    url: photo.url
                )
            }
            if let idx = featuredSlots.firstIndex(where: { $0.position == position }) {
                featuredSlots[idx] = LNFeaturedSlot(position: position, photo: newFeaturedPhoto)
            }
        } catch {
            print("Error setting featured:", error)
        }
        pickerSlot = nil
    }
}
