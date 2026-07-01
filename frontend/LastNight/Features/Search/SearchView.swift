import SwiftUI
import Contacts

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var results: [User] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var navigationPath = NavigationPath()
    @State private var suggestedUsers: [SuggestedUser] = []
    @State private var isLoadingSuggestions = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.black.ignoresSafeArea()

                if query.count < 2 {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if !suggestedUsers.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("people you may know")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                        .padding(.top, 16)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(suggestedUsers) { user in
                                                NavigationLink(value: user.username) {
                                                    SuggestedUserCard(user: user)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.bottom, 24)
                            }

                            VStack(spacing: 12) {
                                Spacer().frame(height: suggestedUsers.isEmpty ? 80 : 0)
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.3))
                                Text("search for people")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, suggestedUsers.isEmpty ? 0 : 20)
                        }
                    }
                } else if isSearching {
                    ProgressView().tint(.white).padding(.top, 60)
                } else if results.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 80)
                        Text("no users found")
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { user in
                                NavigationLink(value: user.username) {
                                    SearchResultRow(user: user, onToggleFollow: { updated in
                                        if let idx = results.firstIndex(where: { $0.id == updated.id }) {
                                            results[idx] = updated
                                        }
                                    })
                                }
                                .buttonStyle(.plain)
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    }
                }
            }
            .navigationTitle("search")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { username in
                UserProfileView(username: username)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "search by username or display name")
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                guard newValue.count >= 2 else {
                    results = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await performSearch(newValue)
                }
            }
            .onChange(of: appState.pendingFollowUserId) { _, _ in
                handlePendingFollow()
            }
            .task {
                handlePendingFollow()
            }
            .task { await loadSuggestions() }
            
        }
        .preferredColorScheme(.dark)
    }
    
    private func handlePendingFollow() {
        guard let userId = appState.pendingFollowUserId else { return }
        Task {
            do {
                let user = try await APIClient.shared.getUser(id: userId)
                await MainActor.run {
                    navigationPath.append(user.username)
                    appState.pendingFollowUserId = nil
                }
            } catch {
                print("Error fetching follower profile:", error)
                await MainActor.run { appState.pendingFollowUserId = nil }
            }
        }
    }
    
    private func loadSuggestions() async {
        // Only run if user has already granted contacts permission
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else { return }
        
        guard let hashes = await ContactsMatcher.requestAndHashContacts() else { return }
        isLoadingSuggestions = true
        do {
            suggestedUsers = try await APIClient.shared.matchContacts(hashes: hashes)
        } catch {
            print("Suggestions error:", error)
        }
        isLoadingSuggestions = false
    }
    
    private func performSearch(_ q: String) async {
        isSearching = true
        do {
            results = try await APIClient.shared.searchUsers(query: q)
        } catch {
            print("Search error:", error)
        }
        isSearching = false
    }
}

struct SearchResultRow: View {
    let user: User
    var onToggleFollow: (User) -> Void
    @State private var isFollowing: Bool
    @State private var isLoading = false

    init(user: User, onToggleFollow: @escaping (User) -> Void) {
        self.user = user
        self.onToggleFollow = onToggleFollow
        _isFollowing = State(initialValue: user.isFollowing ?? false)
    }

    var body: some View {
        HStack(spacing: 14) {
            if let urlStr = user.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.1))
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(user.displayName.prefix(1))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button {
                toggleFollow()
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView().tint(isFollowing ? .white : .black)
                    } else {
                        Text(isFollowing ? "following" : "follow")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isFollowing ? .white : .black)
                    }
                }
                .frame(width: 84, height: 32)
                .background(isFollowing ? Color.white.opacity(0.15) : Color.white)
                .cornerRadius(16)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func toggleFollow() {
        isLoading = true
        Task {
            do {
                if isFollowing {
                    try await APIClient.shared.unfollowUser(id: user.id)
                } else {
                    try await APIClient.shared.followUser(id: user.id)
                }
                isFollowing.toggle()
                var updated = user
                updated.isFollowing = isFollowing
                onToggleFollow(updated)
            } catch {
                print("Follow toggle error:", error)
            }
            isLoading = false
        }
    }
}

struct SuggestedUserCard: View {
    let user: SuggestedUser

    var body: some View {
        VStack(spacing: 8) {
            if let urlStr = user.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.1))
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(user.displayName.prefix(1))
                            .foregroundColor(.white)
                            .font(.title3)
                    )
            }

            Text(user.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)

            Text("@\(user.username)")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(width: 90)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}
