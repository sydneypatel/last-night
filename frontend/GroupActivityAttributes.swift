import ActivityKit
import Foundation

struct GroupActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var photoCount: Int
        var unlockDate: Date
    }

    var groupId: String
    var groupName: String
}