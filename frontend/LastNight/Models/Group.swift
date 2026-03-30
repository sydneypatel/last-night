import Foundation

struct Group: Codable, Identifiable {
    let id: String
    let name: String
    let coverPhotoUrl: String?
    let createdBy: String
    let unlockMode: UnlockMode
    let unlockAt: Date?
    let timezone: String
    let isActive: Bool
    let inviteCode: String
    let createdAt: Date
    // Joined from query
    var memberCount: Int?
    var photoCount: Int?
    var role: MemberRole?

    enum UnlockMode: String, Codable {
        case sunrise
        case custom
        case sundayNight = "sunday_night"
    }

    enum MemberRole: String, Codable {
        case owner
        case member
    }

    enum CodingKeys: String, CodingKey {
        case id, name, timezone
        case coverPhotoUrl = "cover_photo_url"
        case createdBy = "created_by"
        case unlockMode = "unlock_mode"
        case unlockAt = "unlock_at"
        case isActive = "is_active"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
        case memberCount = "member_count"
        case photoCount = "photo_count"
        case role
    }
}
