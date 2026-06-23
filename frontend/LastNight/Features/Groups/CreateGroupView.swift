import SwiftUI
import PhotosUI

struct CreateGroupView: View {
    var onCreated: (Group) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var unlockMode: Group.UnlockMode = .sunrise
    @State private var customUnlockDate = Date().addingTimeInterval(86400)
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var selectedItem: PhotosPickerItem?
    @State private var coverImage: UIImage?

    // Share-after-create
    @State private var createdGroup: Group?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 28) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            if let coverImage {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        VStack(spacing: 4) {
                                            Image(systemName: "camera.fill")
                                                .font(.title3)
                                                .foregroundColor(.white.opacity(0.4))
                                            Text("cover")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                    )
                            }
                        }
                    }
                    .onChange(of: selectedItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let img = UIImage(data: data) {
                                coverImage = img
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("group name")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("saturday night, bar crawl, beach day,...", text: $name)
                            .textFieldStyle(LNTextFieldStyle())
                            .autocapitalization(.none)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("photos unlock")
                            .font(.caption)
                            .foregroundColor(.gray)

                        ForEach([Group.UnlockMode.sunrise, .sundayNight, .custom], id: \.self) { mode in
                            unlockModeRow(mode)
                        }
                    }

                    if unlockMode == .custom {
                        DatePicker("unlock at", selection: $customUnlockDate, displayedComponents: [.date, .hourAndMinute])
                            .colorScheme(.dark)
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                    }

                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.caption)
                    }

                    Spacer()

                    Button {
                        create()
                    } label: {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("create group").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(name.isEmpty ? Color.white.opacity(0.2) : Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(14)
                    .disabled(name.isEmpty || isLoading)
                }
                .padding(24)
            }
            .navigationTitle("new group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
            .sheet(item: $createdGroup, onDismiss: {
                // After the share sheet is closed, finish up.
                if let g = createdGroup { onCreated(g) }
                dismiss()
            }) { group in
                ShareInviteView(group: group) {
                    createdGroup = nil
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func create() {
        isLoading = true
        Task {
            do {
                var group = try await APIClient.shared.createGroup(
                    name: name,
                    unlockMode: unlockMode.rawValue,
                    unlockAt: unlockMode == .custom ? customUnlockDate : nil,
                    timezone: TimeZone.current.identifier
                )

                if let coverImage,
                   let imageData = coverImage.jpegData(compressionQuality: 0.8) {
                    do {
                        let (uploadUrl, key) = try await APIClient.shared.getCoverUploadURL(groupId: group.id)
                        var s3Request = URLRequest(url: URL(string: uploadUrl)!)
                        s3Request.httpMethod = "PUT"
                        s3Request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                        s3Request.httpBody = imageData
                        _ = try await URLSession.shared.data(for: s3Request)
                        let coverUrl = "\(Constants.cdnBaseURL)/\(key)"
                        group = try await APIClient.shared.updateGroupCover(groupId: group.id, coverUrl: coverUrl)
                    } catch {
                        print("Cover upload failed (non-fatal):", error)
                    }
                }

                isLoading = false
                createdGroup = group   // shows the share sheet
            } catch APIError.badRequest(let msg) {
                errorMessage = msg
                isLoading = false
            } catch {
                errorMessage = "Something went wrong"
                isLoading = false
            }
        }
    }

    private func unlockModeRow(_ mode: Group.UnlockMode) -> some View {
        Button {
            unlockMode = mode
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                if unlockMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(unlockMode == mode ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}

// MARK: - Share invite sheet (shown right after group creation)

struct ShareInviteView: View {
    let group: Group
    var onDone: () -> Void
    @State private var copied = false
    @State private var codeCopied = false
    @State private var showingAddMembers = false

    private var inviteLink: String { InviteCode.link(for: group.inviteCode) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("'\(group.name)' is live!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("invite your friends to join the group by sharing the link below:")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                // Link display
                Text(inviteLink)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                

                // Copy + Share
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = inviteLink
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "copied!" : "copy")
                        }
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(14)
                    }

                    ShareLink(item: URL(string: inviteLink)!,
                              message: Text("join my group on last night :)")) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("share")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 32)
                
                Button {
                    showingAddMembers = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("add friends")
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 32)
                
                // Tappable code fallback
                Button {
                    UIPasteboard.general.string = group.inviteCode
                    withAnimation { codeCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { codeCopied = false }
                    }
                } label: {
                    Text(codeCopied ? "copied!" : "or share code: \(group.inviteCode)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button {
                    onDone()
                } label: {
                    Text("done")
                        .foregroundColor(.gray)
                        .padding()
                }
                
                
            }
        }
        .sheet(isPresented: $showingAddMembers) {
            AddMembersView(groupId: group.id, groupName: group.name)
        }
        .preferredColorScheme(.dark)
    }
}

extension Group.UnlockMode {
    var label: String {
        switch self {
        case .sunrise: return "at sunrise"
        case .sundayNight: return "sunday night"
        case .custom: return "custom time"
        }
    }
    var description: String {
        switch self {
        case .sunrise: return "photos unlock the next morning"
        case .sundayNight: return "perfect for weekend trips"
        case .custom: return "you choose when they reveal"
        }
    }
}
