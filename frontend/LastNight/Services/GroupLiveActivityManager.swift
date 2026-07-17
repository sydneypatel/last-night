//
//  GroupLiveActivityManager.swift
//  LastNight
//
//  Created by Sydney Patel on 7/17/26.
//


import ActivityKit
import Foundation

@MainActor
enum GroupLiveActivityManager {

    /// Call this when the first photo is taken in a group.
    static func start(groupId: String, groupName: String, unlockDate: Date, photoCount: Int) {
        // Don't start a duplicate if one's already running for this group.
        guard !Activity<GroupActivityAttributes>.activities.contains(where: { $0.attributes.groupId == groupId }) else {
            return
        }

        let attributes = GroupActivityAttributes(groupId: groupId, groupName: groupName)
        let initialState = GroupActivityAttributes.ContentState(
            photoCount: photoCount,
            unlockDate: unlockDate
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: unlockDate),
                pushType: .token
            )
            print("Started Live Activity for group \(groupId): \(activity.id)")

            // Send the push token to your backend so it can push updates/end the activity later.
            Task {
                for await tokenData in activity.pushTokenUpdates {
                    let token = tokenData.map { String(format: "%02x", $0) }.joined()
                    try? await APIClient.shared.registerLiveActivityToken(groupId: groupId, token: token)
                }
            }
        } catch {
            print("Failed to start Live Activity:", error)
        }
    }

    /// Call this whenever a new photo is taken, to bump the count locally.
    static func updatePhotoCount(groupId: String, newCount: Int) {
        guard let activity = Activity<GroupActivityAttributes>.activities.first(where: { $0.attributes.groupId == groupId }) else {
            return
        }
        Task {
            var state = activity.content.state
            state.photoCount = newCount
            await activity.update(.init(state: state, staleDate: state.unlockDate))
        }
    }

    /// Local fallback: end the activity if the app is foregrounded past unlock time.
    static func endIfPastUnlock(groupId: String) {
        guard let activity = Activity<GroupActivityAttributes>.activities.first(where: { $0.attributes.groupId == groupId }) else {
            return
        }
        if activity.content.state.unlockDate <= Date() {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}