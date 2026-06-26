import SwiftUI

struct MembersView: View {
    let groupId: String
    let isOwner: Bool
    @Environment(\.dismiss) var dismiss
    @State private var members: [MemberRow] = []
    @State private var isLoading = true
    @State private var memberToRemove: MemberRow? = nil
    @State private var isRemoving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.white)
                } else if members.isEmpty {
                    Text("no members found")
                        .foregroundColor(.gray)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(members) { member in
                                HStack(spacing: 14) {
                                    NavigationLink(destination: UserProfileView(username: member.username)) {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(0.1))
                                                    .frame(width: 44, height: 44)

                                                if let avatarUrl = member.avatarUrl,
                                                   let url = URL(string: avatarUrl) {
                                                    AsyncImage(url: url) { image in
                                                        image.resizable().scaledToFill()
                                                    } placeholder: {
                                                        Text(member.displayName.prefix(1))
                                                            .foregroundColor(.white)
                                                            .font(.subheadline)
                                                    }
                                                    .frame(width: 44, height: 44)
                                                    .clipShape(Circle())
                                                } else {
                                                    Text(member.displayName.prefix(1))
                                                        .foregroundColor(.white)
                                                        .font(.subheadline)
                                                }
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(member.displayName)
                                                    .foregroundColor(.white)
                                                    .fontWeight(.medium)
                                                Text("@\(member.username)")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }

                                            Spacer()

                                            if member.role == "owner" {
                                                Text("owner")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.white.opacity(0.08))
                                                    .cornerRadius(6)
                                            }

                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.gray.opacity(0.5))
                                        }
                                    }

                                    if isOwner && member.role != "owner" {
                                        Button {
                                            memberToRemove = member
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red.opacity(0.8))
                                                .font(.title3)
                                        }
                                        .padding(.leading, 4)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
            .navigationTitle("members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .task { await loadMembers() }
            .alert("remove member?", isPresented: Binding(
                get: { memberToRemove != nil },
                set: { if !$0 { memberToRemove = nil } }
            )) {
                Button("remove", role: .destructive) {
                    if let member = memberToRemove {
                        Task { await removeMember(member) }
                    }
                }
                Button("cancel", role: .cancel) { memberToRemove = nil }
            } message: {
                Text("remove \(memberToRemove?.displayName ?? "") from the group?")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadMembers() async {
        do {
            let (_, fetchedMembers) = try await APIClient.shared.getGroup(id: groupId)
            members = fetchedMembers.map {
                MemberRow(id: $0.id, username: $0.username, displayName: $0.displayName, role: $0.role ?? "member", avatarUrl: $0.avatarUrl)
            }
        } catch {
            print("Error loading members:", error)
        }
        isLoading = false
    }

    private func removeMember(_ member: MemberRow) async {
        do {
            try await APIClient.shared.removeMember(groupId: groupId, userId: member.id)
            await MainActor.run {
                members.removeAll { $0.id == member.id }
                memberToRemove = nil
            }
        } catch {
            print("Error removing member:", error)
            await MainActor.run { memberToRemove = nil }
        }
    }
}

struct MemberRow: Identifiable {
    let id: String
    let username: String
    let displayName: String
    let role: String
    let avatarUrl: String?
}
