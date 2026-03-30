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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        timezone = try c.decode(String.self, forKey: .timezone)
        coverPhotoUrl = try c.decodeIfPresent(String.self, forKey: .coverPhotoUrl)
        createdBy = try c.decode(String.self, forKey: .createdBy)
        unlockMode = try c.decode(UnlockMode.self, forKey: .unlockMode)
        unlockAt = try c.decodeIfPresent(Date.self, forKey: .unlockAt)
        isActive = try c.decode(Bool.self, forKey: .isActive)
        inviteCode = try c.decode(String.self, forKey: .inviteCode)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        role = try c.decodeIfPresent(MemberRole.self, forKey: .role)

        // Postgres returns COUNT() as String — handle both
        if let intVal = try? c.decodeIfPresent(Int.self, forKey: .memberCount) {
            memberCount = intVal
        } else if let strVal = try? c.decodeIfPresent(String.self, forKey: .memberCount) {
            memberCount = Int(strVal)
        }

        if let intVal = try? c.decodeIfPresent(Int.self, forKey: .photoCount) {
            photoCount = intVal
        } else if let strVal = try? c.decodeIfPresent(String.self, forKey: .photoCount) {
            photoCount = Int(strVal)
        }
    }
}
