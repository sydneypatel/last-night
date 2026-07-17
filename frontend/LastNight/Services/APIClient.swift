import Foundation
import FirebaseAuth

enum APIError: Error {
    case notFound
    case unauthorized
    case badRequest(String)
    case serverError(String)
    case decodingError
}

class APIClient {
    static let shared = APIClient()
    private let baseURL = Constants.apiBaseURL
    
    private init() {}
    
    // MARK: - Core request method
    
    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.badRequest("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Attach Firebase token
        if let token = try? await Auth.auth().currentUser?.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        switch statusCode {
        case 200...201: break
        case 400:
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Bad request"
            throw APIError.badRequest(msg)
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        case 409:
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Conflict"
            throw APIError.badRequest(msg)
        default:
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Server error"
            throw APIError.serverError(msg)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(T.self, from: data) else {
            throw APIError.decodingError
        }
        return decoded
    }
    
    // MARK: - Auth
    
    func register(username: String, displayName: String, timezone: String) async throws -> User {
        let response: UserResponse = try await request(
            path: "/auth/register",
            method: "POST",
            body: ["username": username, "displayName": displayName, "timezone": timezone]
        )
        return response.user
    }
    
    func syncUser() async throws -> User {
        let response: UserResponse = try await request(path: "/auth/sync", method: "POST")
        return response.user
    }
    
    func updateProfile(displayName: String, avatarUrl: String? = nil, bio: String? = nil) async throws -> User {
        var body: [String: Any] = ["displayName": displayName]
        if let avatarUrl { body["avatarUrl"] = avatarUrl }
        if let bio { body["bio"] = bio }
        let response: UserResponse = try await request(
            path: "/auth/profile",
            method: "PATCH",
            body: body
        )
        return response.user
    }
    
    func getAvatarUploadURL() async throws -> (uploadUrl: String, key: String) {
        struct AvatarURLResponse: Decodable { let uploadUrl: String; let key: String }
        let response: AvatarURLResponse = try await request(
            path: "/auth/avatar-upload-url",
            method: "POST"
        )
        return (response.uploadUrl, response.key)
    }
    
    func deleteAccount() async throws {
        let _: EmptyResponse = try await request(path: "/auth/account", method: "DELETE")
    }
    
    // MARK: - Notifications
    
    func registerDeviceToken(_ token: String, environment: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/notifications/device-token",
            method: "POST",
            body: ["token": token, "environment": environment]
        )
    }
    
    func unregisterDeviceToken(_ token: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/notifications/device-token",
            method: "DELETE",
            body: ["token": token]
        )
    }
    
    func registerLiveActivityToken(groupId: String, token: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/notifications/live-activity-token",
            method: "POST",
            body: ["groupId": groupId, "token": token]
        )
    }
    
    // MARK: - Social
    
    func getUser(id: String) async throws -> User {
        let response: UserResponse = try await request(path: "/users/by-id/\(id)")
        return response.user
    }
    
    func searchUsers(query: String) async throws -> [User] {
        let response: UsersResponse = try await request(path: "/users/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
        return response.users
    }
    
    func getUserProfile(username: String) async throws -> User {
        let response: UserResponse = try await request(path: "/users/\(username)")
        return response.user
    }
    
    func followUser(id: String) async throws {
        let _: FollowResponse = try await request(path: "/users/\(id)/follow", method: "POST")
    }
    
    func unfollowUser(id: String) async throws {
        let _: FollowResponse = try await request(path: "/users/\(id)/follow", method: "DELETE")
    }
    
    func getFollowers(userId: String) async throws -> [User] {
        let response: UsersResponse = try await request(path: "/users/\(userId)/followers")
        return response.users
    }
    
    func getFollowing(userId: String) async throws -> [User] {
        let response: UsersResponse = try await request(path: "/users/\(userId)/following")
        return response.users
    }
    
    // MARK: - Groups
    
    func getGroups() async throws -> [Group] {
        let response: GroupsResponse = try await request(path: "/groups")
        return response.groups
    }
    
    func createGroup(name: String, unlockMode: String, unlockAt: Date?, timezone: String) async throws -> Group {
        var body: [String: Any] = ["name": name, "unlockMode": unlockMode, "timezone": timezone]
        if let unlockAt {
            body["unlockAt"] = ISO8601DateFormatter().string(from: unlockAt)
        }
        let response: GroupResponse = try await request(path: "/groups", method: "POST", body: body)
        return response.group
    }
    
    func joinGroup(inviteCode: String) async throws -> Group {
        let response: GroupResponse = try await request(
            path: "/groups/join",
            method: "POST",
            body: ["inviteCode": inviteCode]
        )
        return response.group
    }
    
    func getGroup(id: String) async throws -> (Group, [User]) {
        let response: GroupDetailResponse = try await request(path: "/groups/\(id)")
        return (response.group, response.members)
    }
    
    func getGroupByCode(_ code: String) async throws -> (group: Group, isMember: Bool) {
        struct ByCodeResponse: Decodable { let group: Group; let isMember: Bool }
        let response: ByCodeResponse = try await request(path: "/groups/by-code/\(code)")
        return (response.group, response.isMember)
    }
    
    func updateUnlockTime(groupId: String, unlockMode: String, unlockAt: Date?) async throws -> Group {
        var body: [String: Any] = [
            "unlockMode": unlockMode,
            "timezone": TimeZone.current.identifier
        ]
        if let unlockAt {
            body["unlockAt"] = ISO8601DateFormatter().string(from: unlockAt)
        }
        let response: GroupResponse = try await request(
            path: "/groups/\(groupId)/unlock",
            method: "PATCH",
            body: body
        )
        return response.group
    }
    
    func leaveOrDeleteGroup(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/groups/\(id)", method: "DELETE")
    }
    
    func addMember(groupId: String, userId: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/groups/\(groupId)/add-member",
            method: "POST",
            body: ["userId": userId]
        )
    }
    
    func removeMember(groupId: String, userId: String) async throws {
        struct RemoveResponse: Decodable { let removed: Bool }
        let _: RemoveResponse = try await request(
            path: "/groups/\(groupId)/members/\(userId)",
            method: "DELETE",
            body: nil
        )
    }
    
    func getCoverUploadURL(groupId: String) async throws -> (uploadUrl: String, key: String) {
        struct CoverURLResponse: Decodable { let uploadUrl: String; let key: String }
        let response: CoverURLResponse = try await request(
            path: "/groups/\(groupId)/cover-upload-url",
            method: "POST"
        )
        return (response.uploadUrl, response.key)
    }
    
    func updateGroupCover(groupId: String, coverUrl: String) async throws -> Group {
        let response: GroupResponse = try await request(
            path: "/groups/\(groupId)/cover",
            method: "PATCH",
            body: ["coverUrl": coverUrl]
        )
        return response.group
    }
    
    func renameGroup(id: String, name: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/groups/\(id)/name",
            method: "PATCH",
            body: ["name": name]
        )
    }
    
    func leaveGroup(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/groups/\(id)/leave", method: "DELETE")
    }
    
    // MARK: - Photos
    
    func getUploadURL(groupId: String, contentType: String = "image/jpeg") async throws -> UploadURLResponse {
        return try await request(
            path: "/photos/upload-url",
            method: "POST",
            body: ["groupId": groupId, "contentType": contentType]
        )
    }

    func confirmUpload(groupId: String, s3Key: String, thumbnailKey: String, mediaType: String = "photo", durationSeconds: Double? = nil) async throws -> Photo {
        var body: [String: Any] = ["groupId": groupId, "s3Key": s3Key, "thumbnailKey": thumbnailKey, "mediaType": mediaType]
        if let durationSeconds { body["durationSeconds"] = durationSeconds }
        let response: PhotoResponse = try await request(
            path: "/photos/confirm",
            method: "POST",
            body: body
        )
        return response.photo
    }
    
    func getPhotos(groupId: String) async throws -> [Photo] {
        let response: PhotosResponse = try await request(path: "/photos/group/\(groupId)")
        return response.photos
    }
    
    func savePhoto(photoId: String) async throws {
        let _: EmptyResponse = try await request(path: "/photos/\(photoId)/save", method: "POST")
    }
    
    func deletePhoto(photoId: String) async throws {
        let _: EmptyResponse = try await request(path: "/photos/\(photoId)", method: "DELETE")
    }
    
    func reportPhoto(photoId: String, reason: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/reports/photo/\(photoId)",
            method: "POST",
            body: ["reason": reason]
        )
    }
    
    // MARK: - Library
    
    func getLibrary() async throws -> [Photo] {
        let response: PhotosResponse = try await request(path: "/library")
        return response.photos
    }
    
    func removeFromLibrary(photoId: String) async throws {
        let _: EmptyResponse = try await request(path: "/library/\(photoId)", method: "DELETE")
    }
    
    // MARK: - Featured
    
    func getFeaturedGrid(username: String) async throws -> [LNFeaturedSlot] {
        let response: LNFeaturedGrid = try await request(path: "/featured/\(username)")
        return response.grid
    }
    
    func setFeaturedPhoto(position: Int, photoId: String?) async throws {
        var body: [String: Any] = [:]
        if let photoId { body["photoId"] = photoId }
        let _: EmptyResponse = try await request(
            path: "/featured/me/\(position)",
            method: "PUT",
            body: body
        )
    }
    
    func getMyPhotosForFeaturing() async throws -> [Photo] {
        let response: PhotosResponse = try await request(path: "/featured/me/library")
        return response.photos
    }
    
    // MARK: - Contacts
    
    func savePhoneHash(_ hash: String) async throws {
        struct Response: Decodable { let saved: Bool }
        let _: Response = try await request(
            path: "/contacts/phone",
            method: "PATCH",
            body: ["phoneHash": hash]
        )
    }

    func matchContacts(hashes: [String]) async throws -> [SuggestedUser] {
        struct Response: Decodable { let matches: [SuggestedUser] }
        let response: Response = try await request(
            path: "/contacts/match",
            method: "POST",
            body: ["hashes": hashes]
        )
        return response.matches
    }
    
    // MARK: - Admin / Reports
    
    struct AdminReport: Decodable, Identifiable {
        let id: String
        let reason: String
        let createdAt: String
        let photoId: String
        let url: String
        let photoOwnerUsername: String
        let reporterUsername: String
        
        enum CodingKeys: String, CodingKey {
            case id, reason, url
            case createdAt = "created_at"
            case photoId = "photo_id"
            case photoOwnerUsername = "photo_owner_username"
            case reporterUsername = "reporter_username"
        }
    }
    
    func getPendingReports() async throws -> [AdminReport] {
        struct Response: Decodable { let reports: [AdminReport] }
        let response: Response = try await request(path: "/reports/admin/pending")
        return response.reports
    }
    
    func dismissReport(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/reports/admin/\(id)/dismiss", method: "POST")
    }
    
    func removeReportedPhoto(reportId: String) async throws {
        let _: EmptyResponse = try await request(path: "/reports/admin/\(reportId)/remove", method: "POST")
    }
    
    // MARK: - Blocking
    
    func blockUser(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/blocks/\(id)", method: "POST")
    }
    
    func unblockUser(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/blocks/\(id)", method: "DELETE")
    }
    
    func getBlockedUsers() async throws -> [User] {
        let response: UsersResponse = try await request(path: "/blocks")
        return response.users
    }
}

// MARK: - Response types

private struct UserResponse: Decodable { let user: User }
private struct GroupsResponse: Decodable { let groups: [Group] }
private struct GroupResponse: Decodable { let group: Group }
private struct GroupDetailResponse: Decodable { let group: Group; let members: [User] }
private struct PhotoResponse: Decodable { let photo: Photo }
private struct PhotosResponse: Decodable { let photos: [Photo] }
private struct EmptyResponse: Decodable {}
private struct UsersResponse: Decodable { let users: [User] }
private struct FollowResponse: Decodable { let following: Bool }

struct UploadURLResponse: Decodable {
    let uploadUrl: String
    let photoId: String
    let s3Key: String
    let thumbnailKey: String
}
