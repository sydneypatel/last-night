import Foundation

struct Photo: Codable, Identifiable {
    let id: String
    let groupId: String
    let userId: String
    let s3Key: String?
    let thumbnailKey: String?
    let locked: Bool
    let capturedAt: Date?
    let unlockedAt: Date?
    let url: String?
    let username: String?
    let displayName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, locked, url, username
        case groupId = "group_id"
        case userId = "user_id"
        case s3Key = "s3_key"
        case thumbnailKey = "thumbnail_key"
        case capturedAt = "captured_at"
        case unlockedAt = "unlocked_at"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}
