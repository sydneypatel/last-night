//
//  BlockedUsersView.swift
//  LastNight
//
//  Created by Sydney Patel on 6/23/26.
//


import SwiftUI

struct BlockedUsersView: View {
    @State private var blockedUsers: [User] = []
    @State private var isLoading = true
    @State private var unblockingId: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else if blockedUsers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "hand.raised")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.3))
                    Text("no blocked users")
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(blockedUsers) { user in
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
                                        .overlay(Text(user.displayName.prefix(1)).foregroundColor(.white))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName).fontWeight(.medium).foregroundColor(.white)
                                    Text("@\(user.username)").font(.caption).foregroundColor(.gray)
                                }

                                Spacer()

                                Button {
                                    unblock(user)
                                } label: {
                                    Text("unblock")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                        .frame(width: 84, height: 32)
                                        .background(Color.white)
                                        .cornerRadius(16)
                                }
                                .disabled(unblockingId == user.id)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }
        }
        .navigationTitle("blocked users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadBlocked() }
        .preferredColorScheme(.dark)
    }

    private func loadBlocked() async {
        do {
            blockedUsers = try await APIClient.shared.getBlockedUsers()
        } catch {
            print("Error loading blocked users:", error)
        }
        isLoading = false
    }

    private func unblock(_ user: User) {
        unblockingId = user.id
        Task {
            do {
                try await APIClient.shared.unblockUser(id: user.id)
                await MainActor.run {
                    blockedUsers.removeAll { $0.id == user.id }
                    unblockingId = nil
                }
            } catch {
                print("Unblock error:", error)
                await MainActor.run { unblockingId = nil }
            }
        }
    }
}