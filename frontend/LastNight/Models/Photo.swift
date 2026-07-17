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
    let groupName: String?
    let displayName: String?
    let avatarUrl: String?
    let mediaType: MediaType
    let durationSeconds: Double?

    enum MediaType: String, Codable {
        case photo
        case video
    }

    enum CodingKeys: String, CodingKey {
        case id, locked, url, username
        case groupId = "group_id"
        case userId = "user_id"
        case s3Key = "s3_key"
        case thumbnailKey = "thumbnail_key"
        case capturedAt = "captured_at"
        case unlockedAt = "unlocked_at"
        case groupName = "group_name"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case mediaType = "media_type"
        case durationSeconds = "duration_seconds"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        groupId = try c.decode(String.self, forKey: .groupId)
        userId = try c.decode(String.self, forKey: .userId)
        s3Key = try c.decodeIfPresent(String.self, forKey: .s3Key)
        thumbnailKey = try c.decodeIfPresent(String.self, forKey: .thumbnailKey)
        locked = try c.decode(Bool.self, forKey: .locked)
        capturedAt = try c.decodeIfPresent(Date.self, forKey: .capturedAt)
        unlockedAt = try c.decodeIfPresent(Date.self, forKey: .unlockedAt)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        groupName = try c.decodeIfPresent(String.self, forKey: .groupName)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        mediaType = try c.decodeIfPresent(MediaType.self, forKey: .mediaType) ?? .photo
        // Postgres NUMERIC can decode as String depending on driver — handle both
        if let doubleVal = try? c.decodeIfPresent(Double.self, forKey: .durationSeconds) {
            durationSeconds = doubleVal
        } else if let strVal = try? c.decodeIfPresent(String.self, forKey: .durationSeconds) {
            durationSeconds = Double(strVal)
        } else {
            durationSeconds = nil
        }
    }
}
