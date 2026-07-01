import Foundation

struct User: Codable, Identifiable {
    let id: String
    let firebaseUid: String?
    let username: String
    let displayName: String
    let avatarUrl: String?
    let timezone: String?
    let bio: String?
    let createdAt: Date?
    var role: String?

    // Follow-related (only present on search results / public profile lookups)
    var isFollowing: Bool?
    var followerCount: Int?
    var followingCount: Int?
    var hasPhone: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case firebaseUid = "firebase_uid"
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case timezone
        case bio
        case createdAt = "created_at"
        case role
        case isFollowing = "is_following"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case hasPhone = "has_phone"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        firebaseUid = try c.decodeIfPresent(String.self, forKey: .firebaseUid)
        username = try c.decode(String.self, forKey: .username)
        displayName = try c.decode(String.self, forKey: .displayName)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        timezone = try c.decodeIfPresent(String.self, forKey: .timezone)
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        isFollowing = try c.decodeIfPresent(Bool.self, forKey: .isFollowing)
        hasPhone = try c.decodeIfPresent(Bool.self, forKey: .hasPhone)

        // Postgres COUNT() can come back as String or Int — handle both
        if let intVal = try? c.decodeIfPresent(Int.self, forKey: .followerCount) {
            followerCount = intVal
        } else if let strVal = try? c.decodeIfPresent(String.self, forKey: .followerCount) {
            followerCount = Int(strVal)
        }

        if let intVal = try? c.decodeIfPresent(Int.self, forKey: .followingCount) {
            followingCount = intVal
        } else if let strVal = try? c.decodeIfPresent(String.self, forKey: .followingCount) {
            followingCount = Int(strVal)
        }
    }
}
