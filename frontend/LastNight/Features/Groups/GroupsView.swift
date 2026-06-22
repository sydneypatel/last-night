import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var appState: AppState
    @State private var groups: [Group] = []
    @State private var isLoading = true
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    @State private var showingHelp = false
    @State private var inviteCode = ""
    @State private var toastMessage: String?
    @State private var joinError: String?
    @State private var navigationPath = NavigationPath()
    @State private var shareGroup: Group?      // drives the share sheet
    @State private var previewGroup: Group?    // drives the custom long-press popup
    @State private var pressedGroupId: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.white)
                } else if groups.isEmpty {
                    VStack(spacing: 16) {
                        Text("no groups yet")
                            .foregroundColor(.gray)
                        Button("create or join one") {
                            showingCreateGroup = true
                        }
                        .foregroundColor(.white)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(groups) { group in
                                GroupRowView(group: group, isPressed: pressedGroupId == group.id)
                                    .onTapGesture {
                                        navigationPath.append(group)
                                    }
                                    .onLongPressGesture(
                                        minimumDuration: 0.2,
                                        pressing: { pressing in
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                pressedGroupId = pressing ? group.id : nil
                                            }
                                        },
                                        perform: {
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            pressedGroupId = nil
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                previewGroup = group
                                            }
                                        }
                                    )
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadGroups()
                    }
                }

                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(20)
                            .padding(.bottom, 100)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: toastMessage)
                }
            }
            .navigationTitle("groups")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // help button start
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark")
                    }
                    // help button end
                    Button {
                        showingJoinGroup = true
                    } label: {
                        Image(systemName: "link")
                    }
                    Button {
                        showingCreateGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: Group.self) { group in
                GroupFeedView(group: group)
            }
            .task { await loadGroups() }
            .onChange(of: appState.pendingGroupId) { _, groupId in
                guard let groupId else { return }
                if let group = groups.first(where: { $0.id == groupId }) {
                    navigationPath.append(group)
                    appState.pendingGroupId = nil
                } else {
                    Task {
                        await loadGroups()
                        if let group = groups.first(where: { $0.id == groupId }) {
                            navigationPath.append(group)
                        }
                        appState.pendingGroupId = nil
                    }
                }
            }
            .fullScreenCover(isPresented: $showingHelp) {
                OnboardingView {
                    showingHelp = false
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView(onCreated: { newGroup in
                    groups.insert(newGroup, at: 0)
                })
            }
            .sheet(item: $shareGroup) { group in
                ShareSheet(items: [
                    "join my group on last night :)",
                    URL(string: InviteCode.link(for: group.inviteCode))!
                ])
            }
            .alert("join a group", isPresented: $showingJoinGroup) {
                TextField("paste invite link or code", text: $inviteCode)
                    .autocapitalization(.allCharacters)
                Button("join") { joinGroup() }
                Button("cancel", role: .cancel) {}
            }
            .alert("couldn't join", isPresented: Binding(
                get: { joinError != nil },
                set: { if !$0 { joinError = nil } }
            )) {
                Button("ok", role: .cancel) { joinError = nil }
            } message: {
                Text(joinError ?? "")
            }
        }
        .preferredColorScheme(.dark)
        // Custom long-press popup overlay
        .overlay {
            if let group = previewGroup {
                GroupPreviewPopup(
                    group: group,
                    onShare: {
                        let g = group
                        dismissPreview()
                        // slight delay so the popup dismiss animation finishes before the sheet
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            shareGroup = g
                        }
                    },
                    onCopy: {
                        UIPasteboard.general.string = InviteCode.link(for: group.inviteCode)
                        dismissPreview()
                        showToast("invite link copied")
                    },
                    onDismiss: { dismissPreview() }
                )
            }
        }
    }

    private func dismissPreview() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            previewGroup = nil
        }
    }

    private func loadGroups() async {
        do {
            groups = try await APIClient.shared.getGroups()
        } catch {
            print("Error loading groups:", error)
        }
        isLoading = false
    }

    private func joinGroup() {
        guard let code = InviteCode.parse(inviteCode) else {
            joinError = "enter a valid invite code or link"
            return
        }
        Task {
            do {
                let group = try await APIClient.shared.joinGroup(inviteCode: code)
                groups.insert(group, at: 0)
                inviteCode = ""
            } catch APIError.serverError(let msg) {
                joinError = msg
            } catch {
                joinError = "Something went wrong, try again"
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toastMessage = nil }
        }
    }
}

struct GroupRowView: View {
    let group: Group
    var isPressed: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if let urlStr = group.coverPhotoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.white.opacity(0.08)
                    }
                } else {
                    Color.white.opacity(0.08)
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("\(group.memberCount ?? 0) \(group.memberCount == 1 ? "member" : "members") · \(group.photoCount ?? 0) \(group.photoCount == 1 ? "photo" : "photos")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(isPressed ? 0.12 : 0.05))
        .cornerRadius(16)
    }
}

// MARK: - Custom long-press popup

struct GroupPreviewPopup: View {
    let group: Group
    var onShare: () -> Void
    var onCopy: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Strong blurred + dimmed backdrop — tap to dismiss
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.4).ignoresSafeArea())
                .onTapGesture { onDismiss() }
                .transition(.opacity)

            // The card
            VStack(spacing: 0) {
                ZStack {
                    if let urlStr = group.coverPhotoUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.white.opacity(0.08)
                        }
                    } else {
                        Color.white.opacity(0.08)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .frame(width: 300, height: 300)
                .clipped()

                VStack(spacing: 16) {
                    Text(group.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        Button {
                            onCopy()
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("copy")
                            }
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(12)
                        }

                        Button {
                            onShare()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("share")
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
            }
            .frame(width: 300)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }
}

// MARK: - iOS share sheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
