//
//  LibraryDetailView.swift
//  LastNight
//
//  Created by Sydney Patel on 4/1/26.
//


import SwiftUI
import Photos

struct LibraryDetailView: View {
    let photo: Photo
    @Environment(\.dismiss) var dismiss
    @State private var showSavedToast = false
    @State private var toastMessage = ""
    @State private var isSavingToPhotos = false
    @State private var showingPinSheet = false
    @State private var featuredSlots: [LNFeaturedSlot] = []
    @State private var isLoadingSlots = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = photo.url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } placeholder: {
                    ProgressView().tint(.white)
                }
            }

            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()

                // Bottom actions
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Save to camera roll
                        Button {
                            saveToCameraRoll()
                        } label: {
                            HStack(spacing: 6) {
                                if isSavingToPhotos {
                                    ProgressView().scaleEffect(0.7).tint(.black)
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.subheadline)
                                }
                                Text("save to photos")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(14)
                        }
                        .disabled(isSavingToPhotos)

                        // Pin to featured
                        Button {
                            showingPinSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pin.fill")
                                    .font(.subheadline)
                                Text("pin to profile")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(14)
                        }
                    }

                    // Photo info
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let username = photo.username {
                                Text("@\(username)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            if let capturedAt = photo.capturedAt {
                                Text(capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Toast
            if showSavedToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                        .padding(.bottom, 140)
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingPinSheet) {
            PinToFeaturedSheet(photo: photo, onPinned: {
                showToast("pinned to your profile!")
            })
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSavedToast = false }
        }
    }

    private func saveToCameraRoll() {
        isSavingToPhotos = true
        guard let url = photo.url, let imageURL = URL(string: url) else {
            isSavingToPhotos = false
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                guard let image = UIImage(data: data) else {
                    await MainActor.run { isSavingToPhotos = false }
                    return
                }

                // Request photo library permission
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized || status == .limited else {
                    await MainActor.run {
                        isSavingToPhotos = false
                        showToast("enable photos access in settings")
                    }
                    return
                }

                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }

                await MainActor.run {
                    isSavingToPhotos = false
                    showToast("saved to camera roll!")
                }
            } catch {
                await MainActor.run {
                    isSavingToPhotos = false
                    showToast("couldn't save, try again")
                }
            }
        }
    }
}

// MARK: - Pin to featured slot picker

struct PinToFeaturedSheet: View {
    let photo: Photo
    var onPinned: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var slots: [LNFeaturedSlot] = (1...9).map { LNFeaturedSlot(position: $0, photo: nil) }
    @State private var isLoading = true
    @State private var isPinning = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("choose a slot")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)

                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(slots) { slot in
                                Button {
                                    pinToSlot(slot.position)
                                } label: {
                                    ZStack {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.05))
                                            .aspectRatio(1, contentMode: .fit)

                                        if slot.photo != nil {
                                            // show replace indicator
                                            Color.white.opacity(0.3)
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .foregroundColor(.white)
                                                .font(.title3)
                                        } else {
                                            Image(systemName: "plus")
                                                .foregroundColor(.white.opacity(0.3))
                                                .font(.title3)
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipped()
                                }
                                .disabled(isPinning)
                            }
                        }
                    }
                    Spacer()
                }
            }
            .navigationTitle("pin to profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
            .task { await loadSlots() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadSlots() async {
        guard let username = appState.currentUser?.username else {
            isLoading = false
            return
        }
        do {
            let fetched = try await APIClient.shared.getFeaturedGrid(username: username)
            slots = (1...9).map { pos in
                fetched.first(where: { $0.position == pos }) ?? LNFeaturedSlot(position: pos, photo: nil)
            }
        } catch {
            print("Error loading slots:", error)
        }
        isLoading = false
    }

    private func pinToSlot(_ position: Int) {
        isPinning = true
        Task {
            do {
                try await APIClient.shared.setFeaturedPhoto(position: position, photoId: photo.id)
                await MainActor.run {
                    isPinning = false
                    onPinned()
                    dismiss()
                }
            } catch {
                await MainActor.run { isPinning = false }
                print("Error pinning:", error)
            }
        }
    }
}
