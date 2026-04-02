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
        default:
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Server error"
            throw APIError.serverError(msg)
        }

        let decoder = JSONDecoder()
        // Temporary debug — remove later
        if let str = String(data: data, encoding: .utf8) {
            print("=== RAW RESPONSE for \(path):", str)
        }
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
    
    func updateProfile(displayName: String, avatarUrl: String? = nil) async throws -> User {
        var body: [String: Any] = ["displayName": displayName]
        if let avatarUrl { body["avatarUrl"] = avatarUrl }
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
    
    func registerDeviceToken(_ token: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/notifications/device-token",
            method: "POST",
            body: ["token": token]
        )
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
    
    func leaveOrDeleteGroup(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/groups/\(id)", method: "DELETE")
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
    
    func leaveGroup(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/groups/\(id)/leave", method: "DELETE")
    }

    // MARK: - Photos

    func getUploadURL(groupId: String) async throws -> UploadURLResponse {
        return try await request(
            path: "/photos/upload-url",
            method: "POST",
            body: ["groupId": groupId, "contentType": "image/jpeg"]
        )
    }

    func confirmUpload(groupId: String, s3Key: String, thumbnailKey: String) async throws -> Photo {
        let response: PhotoResponse = try await request(
            path: "/photos/confirm",
            method: "POST",
            body: ["groupId": groupId, "s3Key": s3Key, "thumbnailKey": thumbnailKey]
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

    // MARK: - Library

    func getLibrary() async throws -> [Photo] {
        let response: PhotosResponse = try await request(path: "/library")
        return response.photos
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
}

// MARK: - Response types

private struct UserResponse: Decodable { let user: User }
private struct GroupsResponse: Decodable { let groups: [Group] }
private struct GroupResponse: Decodable { let group: Group }
private struct GroupDetailResponse: Decodable { let group: Group; let members: [User] }
private struct PhotoResponse: Decodable { let photo: Photo }
private struct PhotosResponse: Decodable { let photos: [Photo] }
private struct EmptyResponse: Decodable {}

struct UploadURLResponse: Decodable {
    let uploadUrl: String
    let photoId: String
    let s3Key: String
    let thumbnailKey: String
}
