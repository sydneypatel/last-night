//
//  SuggestedUser.swift
//  LastNight
//
//  Created by Sydney Patel on 6/27/26.
//


struct SuggestedUser: Identifiable, Decodable {
    let id: String
    let username: String
    let displayName: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}