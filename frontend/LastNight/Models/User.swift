import Foundation

struct User: Codable, Identifiable {
    let id: String
    let firebaseUid: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let timezone: String
    let bio: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case firebaseUid = "firebase_uid"
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case timezone
        case bio
        case createdAt = "created_at"
    }
}
