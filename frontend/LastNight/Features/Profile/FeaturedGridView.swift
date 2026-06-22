import SwiftUI

struct FeaturedGridView: View {
    let slots: [LNFeaturedSlot]
    let isOwner: Bool
    var onSlotTap: ((LNFeaturedSlot) -> Void)?

    @State private var viewerPayload: FeaturedViewerPayload?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    // Filled slots only, in position order — the swipeable sequence.
    private var filledPhotos: [FeaturedPhoto] {
        slots
            .sorted { $0.position < $1.position }
            .compactMap { $0.photo }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(slots) { slot in
                FeaturedSlotCell(slot: slot, isOwner: isOwner)
                    .onTapGesture {
                        handleTap(slot)
                    }
            }
        }
        .fullScreenCover(item: $viewerPayload) { payload in
            FeaturedPhotoViewer(photos: payload.photos, startIndex: payload.startIndex)
        }
    }

    private func handleTap(_ slot: LNFeaturedSlot) {
        if isOwner {
            // Owner keeps the edit/picker flow.
            onSlotTap?(slot)
            return
        }
        // Viewer: only filled slots are tappable.
        guard let photo = slot.photo else { return }
        let filled = filledPhotos
        guard !filled.isEmpty,
              let startIdx = filled.firstIndex(where: { $0.id == photo.id }) else { return }
        viewerPayload = FeaturedViewerPayload(photos: filled, startIndex: startIdx)
    }
}

private struct FeaturedViewerPayload: Identifiable {
    let id = UUID()
    let photos: [FeaturedPhoto]
    let startIndex: Int
}

struct FeaturedSlotCell: View {
    let slot: LNFeaturedSlot
    let isOwner: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.opacity(0.05)

                if let photo = slot.photo, let url = photo.url, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                    } placeholder: {
                        Color.white.opacity(0.05)
                    }
                } else {
                    if isOwner {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }
}
