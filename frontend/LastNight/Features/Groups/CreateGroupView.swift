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

    // Avatar picker
    @State private var selectedItem: PhotosPickerItem?
    @State private var coverImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 28) {

                    // Cover photo picker
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
                        TextField("saturday night, bar crawl...", text: $name)
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

                // Upload cover photo if selected — non-fatal if it fails
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
                        // Group still created, just without cover
                    }
                }

                onCreated(group)
                dismiss()
            } catch APIError.badRequest(let msg) {
                errorMessage = msg
            } catch {
                errorMessage = "Something went wrong"
            }
            isLoading = false
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
