import SwiftUI
import PhotosUI

struct GroupFeedView: View {
    let group: Group
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var showingCamera = false
    @State private var showCopied = false
    @State private var showingMembers = false
    @State private var selectedPhotoIndex: Int?
    @State private var showingLeaveConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var currentGroupName: String = ""

    // Unlock state (mutable so label updates live after editing)
    @State private var currentUnlockMode: Group.UnlockMode = .sunrise
    @State private var currentUnlockAt: Date?
    @State private var showingEditUnlock = false

    // Cover photo state
    @State private var currentCoverUrl: String?
    @State private var showingCoverPhotoSourcePicker = false
    @State private var showingCoverCamera = false
    @State private var showingCoverPhotoPicker = false
    @State private var selectedCoverItem: PhotosPickerItem?
    @State private var isUploadingCover = false
    @State private var showingRenameGroup = false
    @State private var newGroupName = ""

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var isUnlocked: Bool {
        guard let unlockAt = currentUnlockAt else { return false }
        return unlockAt <= Date()
    }

    private var unlockLabel: String {
        guard let unlockAt = currentUnlockAt else {
            switch currentUnlockMode {
            case .sunrise: return "photos unlock at sunrise"
            case .sundayNight: return "photos unlock sunday night"
            case .custom: return "photos unlock at custom time"
            }
        }
        if isUnlocked {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "unlocked \(formatter.string(from: unlockAt))"
        } else {
            switch currentUnlockMode {
            case .sunrise: return "photos unlock at sunrise"
            case .sundayNight: return "photos unlock sunday night"
            case .custom:
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return "unlocks \(formatter.string(from: unlockAt))"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        Button {
                            UIPasteboard.general.string = group.inviteCode
                            withAnimation { showCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showCopied = false }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "link").font(.body)
                                Text("invite code:").font(.caption).foregroundColor(.gray)
                                Text(group.inviteCode).font(.body).fontWeight(.bold).tracking(2)
                                Spacer()
                                Text(showCopied ? "copied!" : "tap to copy").font(.caption).foregroundColor(.gray)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(14)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        HStack(spacing: 6) {
                            Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                                .font(.caption2)
                                .foregroundColor(isUnlocked ? .white.opacity(0.5) : .gray)
                            Text(unlockLabel)
                                .font(.caption)
                                .foregroundColor(isUnlocked ? .white.opacity(0.5) : .gray)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        
                        if photos.isEmpty {
                            VStack(spacing: 12) {
                                Spacer().frame(height: 60)
                                Text("no photos yet").foregroundColor(.gray)
                                Text("be the first to capture the night")
                                    .font(.caption).foregroundColor(.gray.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                                    PhotoGridCell(photo: photo)
                                        .onTapGesture {
                                            if !photo.locked {
                                                selectedPhotoIndex = index
                                            }
                                        }
                                }
                            }
                            .padding(0)
                        }
                    }
                }
                .refreshable {
                    await loadPhotos()
                }
            }

            VStack {
                Spacer()
                Button {
                    showingCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                        .frame(width: 64, height: 64)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .padding(.bottom, 32)
            }

            if isUploadingCover {
                VStack {
                    ProgressView("updating cover photo…")
                        .tint(.white)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                }
            }
        }
        .navigationTitle(currentGroupName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingMembers = true } label: {
                        Label("members", systemImage: "person.2.fill")
                    }
                    Button { showingCoverPhotoSourcePicker = true } label: {
                        Label("change cover photo", systemImage: "photo")
                    }
                    Button {
                        newGroupName = currentGroupName
                        showingRenameGroup = true
                    } label: {
                        Label("rename group", systemImage: "pencil")
                    }
                    if group.role == .owner {
                        Button {
                            showingEditUnlock = true
                        } label: {
                            Label("change unlock time", systemImage: "clock")
                        }
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("delete group", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            showingLeaveConfirm = true
                        } label: {
                            Label("leave group", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .alert("leave \(group.name)?", isPresented: $showingLeaveConfirm) {
            Button("leave group", role: .destructive) { leaveGroup() }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("you won't be able to see this group's photos anymore.")
        }
        .alert("delete \(group.name)?", isPresented: $showingDeleteConfirm) {
            Button("delete group", role: .destructive) { deleteGroup() }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this will permanently delete the group and all photos for everyone.")
        }
        .alert("rename group", isPresented: $showingRenameGroup) {
            TextField("group name", text: $newGroupName)
            Button("save") { renameGroup() }
            Button("cancel", role: .cancel) {}
        }
        .confirmationDialog("change cover photo", isPresented: $showingCoverPhotoSourcePicker) {
            Button("take photo") { showingCoverCamera = true }
            Button("choose from library") { showingCoverPhotoPicker = true }
            Button("cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingCoverPhotoPicker, selection: $selectedCoverItem, matching: .images)
        .onChange(of: selectedCoverItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadCoverPhoto(image: image)
                }
                selectedCoverItem = nil
            }
        }
        .fullScreenCover(isPresented: $showingCoverCamera) {
            CoverCameraView { image in
                Task { await uploadCoverPhoto(image: image) }
            }
        }
        .sheet(isPresented: $showingEditUnlock) {
            EditUnlockTimeView(
                currentMode: currentUnlockMode,
                currentUnlockAt: currentUnlockAt,
                groupId: group.id
            ) { newMode, newUnlockAt in
                currentUnlockMode = newMode
                currentUnlockAt = newUnlockAt
            }
        }
        .task { await loadPhotos() }
        .onAppear {
            currentGroupName = group.name
            currentUnlockMode = group.unlockMode
            currentUnlockAt = group.unlockAt
        }
        .fullScreenCover(isPresented: $showingCamera) {
                    CameraView(groupId: group.id, onPhotoTaken: { newPhoto in
                        if let newPhoto {
                            photos.insert(newPhoto, at: 0)
                        }
                    })
                }
        .sheet(isPresented: $showingMembers) {
            MembersView(groupId: group.id)
        }
        .sheet(isPresented: Binding(
            get: { selectedPhotoIndex != nil },
            set: { if !$0 { selectedPhotoIndex = nil } }
        )) {
            if let index = selectedPhotoIndex {
                PhotoDetailView(
                    photos: photos,
                    startIndex: index,
                    groupName: group.name,
                    onPhotoDeleted: { deletedId in
                        photos.removeAll { $0.id == deletedId }
                    }
                )
                .environmentObject(appState)
            }
        }
    }

    private func loadPhotos() async {
        do {
            photos = try await APIClient.shared.getPhotos(groupId: group.id)
        } catch {
            print("Error loading photos:", error)
        }
        isLoading = false
    }

    private func leaveGroup() {
        Task {
            do {
                try await APIClient.shared.leaveGroup(id: group.id)
                dismiss()
            } catch {
                print("Error leaving group:", error)
            }
        }
    }

    private func deleteGroup() {
        Task {
            do {
                try await APIClient.shared.leaveOrDeleteGroup(id: group.id)
                dismiss()
            } catch {
                print("Error deleting group:", error)
            }
        }
    }
    
    private func renameGroup() {
        guard !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            do {
                try await APIClient.shared.renameGroup(id: group.id, name: newGroupName)
                await MainActor.run {
                    currentGroupName = newGroupName
                }
            } catch {
                print("Error renaming group:", error)
            }
        }
    }

    private func uploadCoverPhoto(image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else { return }
        isUploadingCover = true
        do {
            let urlResponse = try await APIClient.shared.getCoverUploadURL(groupId: group.id)
            guard let uploadURL = URL(string: urlResponse.uploadUrl) else {
                isUploadingCover = false
                return
            }
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            _ = try await URLSession.shared.upload(for: request, from: imageData)

            let cdnUrl = "\(Constants.cdnBaseURL)/\(urlResponse.key)"
            _ = try await APIClient.shared.updateGroupCover(groupId: group.id, coverUrl: cdnUrl)
        } catch {
            print("Error uploading cover photo:", error)
        }
        isUploadingCover = false
    }
}

struct PhotoGridCell: View {
    let photo: Photo

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.opacity(0.05)

                if let url = photo.url, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                            .blur(radius: photo.locked ? 12 : 0)
                    } placeholder: {
                        Color.white.opacity(0.05)
                    }
                }

                if photo.locked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.title3)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }
}

struct EditUnlockTimeView: View {
    let groupId: String
    let onSaved: (Group.UnlockMode, Date?) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var selectedMode: String
    @State private var customDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(currentMode: Group.UnlockMode, currentUnlockAt: Date?, groupId: String, onSaved: @escaping (Group.UnlockMode, Date?) -> Void) {
        self.groupId = groupId
        self.onSaved = onSaved
        switch currentMode {
        case .sunrise: _selectedMode = State(initialValue: "sunrise")
        case .sundayNight: _selectedMode = State(initialValue: "sunday_night")
        case .custom: _selectedMode = State(initialValue: "custom")
        }
        _customDate = State(initialValue: currentUnlockAt ?? Date().addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    Text("when should photos unlock?")
                        .font(.headline)
                        .foregroundColor(.white)

                    VStack(spacing: 0) {
                        modeRow(label: "sunrise", value: "sunrise", subtitle: "next morning at 6:30am")
                        Divider().background(Color.white.opacity(0.1))
                        modeRow(label: "sunday night", value: "sunday_night", subtitle: "this sunday at 11:59pm")
                        Divider().background(Color.white.opacity(0.1))
                        modeRow(label: "custom", value: "custom", subtitle: "pick a date and time")
                    }
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)

                    if selectedMode == "custom" {
                        DatePicker("unlock at", selection: $customDate)
                            .datePickerStyle(.compact)
                            .colorScheme(.dark)
                            .tint(.white)
                            .foregroundColor(.white)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundColor(.red)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("unlock time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }.tint(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Button("save") { save() }.tint(.white).fontWeight(.semibold)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func modeRow(label: String, value: String, subtitle: String) -> some View {
        Button {
            selectedMode = value
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).foregroundColor(.white)
                    Text(subtitle).font(.caption).foregroundColor(.gray)
                }
                Spacer()
                if selectedMode == value {
                    Image(systemName: "checkmark").foregroundColor(.white)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        let unlockAt: Date? = selectedMode == "custom" ? customDate : nil
        Task {
            do {
                let updated = try await APIClient.shared.updateUnlockTime(
                    groupId: groupId,
                    unlockMode: selectedMode,
                    unlockAt: unlockAt
                )
                await MainActor.run {
                    onSaved(updated.unlockMode, updated.unlockAt)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "couldn't update unlock time"
                }
            }
        }
    }
}
