//
//  AddMembersView.swift
//  LastNight
//
//  Created by Sydney Patel on 6/22/26.
//


import SwiftUI

struct AddMembersView: View {
    let groupId: String
    let groupName: String
    @Environment(\.dismiss) var dismiss

    @State private var query = ""
    @State private var results: [User] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var addedIds: Set<String> = []
    @State private var existingMemberIds: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if query.count < 2 {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 80)
                        Image(systemName: "person.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.3))
                        Text("search for people to add")
                            .foregroundColor(.gray)
                    }
                } else if isSearching {
                    ProgressView().tint(.white).padding(.top, 60)
                } else if results.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 80)
                        Text("no users found").foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { user in
                                AddMemberRow(
                                    user: user,
                                    state: rowState(for: user),
                                    onAdd: { addUser(user) }
                                )
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    }
                }
            }
            .navigationTitle("add members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("done") { dismiss() }.tint(.white)
                }
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
            .task { await loadMembers() }
        }
        .preferredColorScheme(.dark)
    }

    private func rowState(for user: User) -> AddMemberRow.RowState {
        if existingMemberIds.contains(user.id) || addedIds.contains(user.id) {
            return .added
        }
        return .canAdd
    }

    private func loadMembers() async {
        do {
            let (_, members) = try await APIClient.shared.getGroup(id: groupId)
            await MainActor.run {
                existingMemberIds = Set(members.map { $0.id })
            }
        } catch {
            print("Error loading members:", error)
        }
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

    private func addUser(_ user: User) {
        Task {
            do {
                try await APIClient.shared.addMember(groupId: groupId, userId: user.id)
                await MainActor.run { addedIds.insert(user.id) }
            } catch {
                print("Add member error:", error)
            }
        }
    }
}

struct AddMemberRow: View {
    enum RowState { case canAdd, added }
    let user: User
    let state: RowState
    var onAdd: () -> Void
    @State private var isLoading = false

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
                    .overlay(Text(user.displayName.prefix(1)).foregroundColor(.white))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName).fontWeight(.medium).foregroundColor(.white)
                Text("@\(user.username)").font(.caption).foregroundColor(.gray)
            }

            Spacer()

            switch state {
            case .added:
                Text("added")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 84, height: 32)
            case .canAdd:
                Button {
                    isLoading = true
                    onAdd()
                } label: {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("add")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                        }
                    }
                    .frame(width: 84, height: 32)
                    .background(Color.white)
                    .cornerRadius(16)
                }
                .disabled(isLoading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
