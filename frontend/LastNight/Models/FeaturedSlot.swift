import Foundation

struct LNFeaturedSlot: Codable, Identifiable {
    let position: Int
    let photo: FeaturedPhoto?
    var id: Int { position }
}

struct FeaturedPhoto: Codable, Identifiable {
    let id: String
    let s3Key: String?
    let locked: Bool?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case id
        case s3Key = "s3_key"
        case locked
        case url
    }
}

struct LNFeaturedGrid: Codable {
    let grid: [LNFeaturedSlot]
}
