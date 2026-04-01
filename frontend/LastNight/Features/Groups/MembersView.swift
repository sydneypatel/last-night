import SwiftUI

struct MembersView: View {
    let groupId: String
    @Environment(\.dismiss) var dismiss
    @State private var members: [MemberRow] = []
    @State private var isLoading = true

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
                                NavigationLink(destination: PublicProfileView(
                                    username: member.username,
                                    displayName: member.displayName
                                )) {
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
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                }
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
        }
        .preferredColorScheme(.dark)
    }

    private func loadMembers() async {
        do {
            let (_, fetchedMembers) = try await APIClient.shared.getGroup(id: groupId)
            members = fetchedMembers.map {
                MemberRow(
                    id: $0.id,
                    username: $0.username,
                    displayName: $0.displayName,
                    role: $0.role ?? "member",
                    avatarUrl: $0.avatarUrl
                )
            }
        } catch {
            print("Error loading members:", error)
        }
        isLoading = false
    }
}

struct MemberRow: Identifiable {
    let id: String
    let username: String
    let displayName: String
    let role: String
    let avatarUrl: String?
}
