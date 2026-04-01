import Foundation

struct LNFeaturedSlot: Codable, Identifiable {
    let position: Int
    let photo: Photo?

    var id: Int { position }
}

struct FeaturedGrid: Codable {
    let grid: [LNFeaturedSlot]
}
