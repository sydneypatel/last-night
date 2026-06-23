import SwiftUI

struct UserProfileView: View {
    let username: String
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var user: User?
    @State private var featuredSlots: [LNFeaturedSlot] = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var isFollowLoading = false
    @State private var showingFollowList: FollowListMode?
    @State private var showingAvatarFullScreen = false
    @State private var showingBlockConfirm = false

    private var isOwnProfile: Bool {
        username.lowercased() == appState.currentUser?.username.lowercased()
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else if let user {
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 10) {
                            SwiftUI.Group {
                                if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
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
                                            Text(user.displayName.prefix(1))
                                                .font(.title)
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            .onTapGesture {
                                showingAvatarFullScreen = true
                            }

                            VStack(spacing: 4) {
                                Text(user.displayName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                if let bio = user.bio, !bio.isEmpty {
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
                                        Text("\(user.followerCount ?? 0)")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        Text("followers")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Button { showingFollowList = .following } label: {
                                    VStack(spacing: 2) {
                                        Text("\(user.followingCount ?? 0)")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        Text("following")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.top, 4)

                            if !isOwnProfile {
                                Button {
                                    toggleFollow()
                                } label: {
                                    ZStack {
                                        if isFollowLoading {
                                            ProgressView().tint(isFollowing ? .white : .black)
                                        } else {
                                            Text(isFollowing ? "following" : "follow")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(isFollowing ? .white : .black)
                                        }
                                    }
                                    .frame(width: 140, height: 40)
                                    .background(isFollowing ? Color.white.opacity(0.15) : Color.white)
                                    .cornerRadius(20)
                                }
                                .disabled(isFollowLoading)
                                .padding(.top, 8)
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 24)

                        HStack {
                            Text("favorites:")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                        FeaturedGridView(slots: featuredSlots, isOwner: false)
                    }
                }
            } else {
                Text("user not found")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("@\(username)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isOwnProfile {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showingBlockConfirm = true
                        } label: {
                            Label("block @\(username)", systemImage: "hand.raised.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .task { await loadProfile() }
        .fullScreenCover(isPresented: $showingAvatarFullScreen) {
            AvatarFullScreenView(
                avatarUrl: user?.avatarUrl,
                fallbackInitial: String(user?.displayName.prefix(1) ?? "?")
            )
        }
        .sheet(item: $showingFollowList) { mode in
            if let user {
                FollowListView(userId: user.id, username: user.username, mode: mode)
            }
        }
        .alert("block @\(username)?", isPresented: $showingBlockConfirm) {
            Button("block", role: .destructive) { blockUser() }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("they won't be able to see your profile or photos, and you won't see theirs. this also unfollows you both.")
        }
        .preferredColorScheme(.dark)
    }

    private func loadProfile() async {
        do {
            let fetchedUser = try await APIClient.shared.getUserProfile(username: username)
            user = fetchedUser
            isFollowing = fetchedUser.isFollowing ?? false

            let fetchedSlots = try await APIClient.shared.getFeaturedGrid(username: username)
            featuredSlots = (1...9).map { pos in
                fetchedSlots.first(where: { $0.position == pos }) ?? LNFeaturedSlot(position: pos, photo: nil)
            }
        } catch {
            print("Error loading profile:", error)
        }
        isLoading = false
    }

    private func toggleFollow() {
        guard let user else { return }
        isFollowLoading = true
        Task {
            do {
                if isFollowing {
                    try await APIClient.shared.unfollowUser(id: user.id)
                } else {
                    try await APIClient.shared.followUser(id: user.id)
                }
                isFollowing.toggle()
            } catch {
                print("Follow toggle error:", error)
            }
            isFollowLoading = false
        }
    }

    private func blockUser() {
        guard let user else { return }
        Task {
            do {
                try await APIClient.shared.blockUser(id: user.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Block error:", error)
            }
        }
    }
}

extension FollowListMode: Identifiable {
    var id: Self { self }
}
