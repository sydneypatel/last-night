import SwiftUI

struct FeaturedGridView: View {
    let slots: [LNFeaturedSlot]
    let isOwner: Bool
    var onSlotTap: ((LNFeaturedSlot) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(slots) { slot in
                FeaturedSlotCell(slot: slot, isOwner: isOwner)
                    .onTapGesture {
                        onSlotTap?(slot)
                    }
            }
        }
    }
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
