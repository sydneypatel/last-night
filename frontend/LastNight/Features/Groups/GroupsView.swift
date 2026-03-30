import SwiftUI

struct GroupsView: View {
    @State private var groups: [Group] = []
    @State private var isLoading = true
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    @State private var inviteCode = ""
    @State private var toastMessage: String?
    @State private var joinError: String?

    var body: some View {
        NavigationStack {
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
                                NavigationLink(destination: GroupFeedView(group: group)) {
                                    GroupRowView(group: group)
                                }
                            }
                        }
                        .padding()
                    }
                }

                // Toast
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
            .navigationTitle("last night")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
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
            .task { await loadGroups() }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView(onCreated: { newGroup in
                    groups.insert(newGroup, at: 0)
                })
            }
            .alert("join a group", isPresented: $showingJoinGroup) {
                TextField("invite code", text: $inviteCode)
                    .autocapitalization(.allCharacters)
                Button("join") { joinGroup() }
                Button("cancel", role: .cancel) {}
            }
            .alert("Couldn't join...", isPresented: Binding(
                get: { joinError != nil },
                set: { if !$0 { joinError = nil } }
            )) {
                Button("ok", role: .cancel) { joinError = nil }
            } message: {
                Text(joinError ?? "")
            }
        }
        .preferredColorScheme(.dark)
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
        Task {
            do {
                let group = try await APIClient.shared.joinGroup(inviteCode: inviteCode)
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
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toastMessage = nil }
        }
    }
}

struct GroupRowView: View {
    let group: Group

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.white.opacity(0.4))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("\(group.memberCount ?? 0) members · \(group.photoCount ?? 0) photos")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
