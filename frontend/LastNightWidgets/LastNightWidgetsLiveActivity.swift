//
//  LastNightWidgetsLiveActivity.swift
//  LastNightWidgets
//
//  Created by Sydney Patel on 7/17/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LastNightWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GroupActivityAttributes.self) { context in
            // Lock screen / banner UI
            HStack(spacing: 14) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.groupName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(context.state.photoCount) photo\(context.state.photoCount == 1 ? "" : "s") so far")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("unlocks at")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    Text(context.state.unlockDate, style: .time)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)
            .widgetURL(URL(string: "lastnight://camera/\(context.attributes.groupId)"))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.unlockDate, style: .timer)
                        .font(.caption)
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.groupName)
                            .font(.headline)
                        Text("\(context.state.photoCount) photos")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("tap to take a photo")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            } compactLeading: {
                Image(systemName: "camera.fill")
                    .foregroundColor(.white)
            } compactTrailing: {
                Text("\(context.state.photoCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            } minimal: {
                Image(systemName: "camera.fill")
                    .foregroundColor(.white)
            }
            .widgetURL(URL(string: "lastnight://camera/\(context.attributes.groupId)"))
        }
    }
}

extension GroupActivityAttributes {
    fileprivate static var preview: GroupActivityAttributes {
        GroupActivityAttributes(groupId: "preview-id", groupName: "friday night")
    }
}

extension GroupActivityAttributes.ContentState {
    fileprivate static var early: GroupActivityAttributes.ContentState {
        GroupActivityAttributes.ContentState(photoCount: 3, unlockDate: .now.addingTimeInterval(3600))
    }

    fileprivate static var almostUnlocked: GroupActivityAttributes.ContentState {
        GroupActivityAttributes.ContentState(photoCount: 12, unlockDate: .now.addingTimeInterval(60))
    }
}

#Preview("Notification", as: .content, using: GroupActivityAttributes.preview) {
   LastNightWidgetsLiveActivity()
} contentStates: {
    GroupActivityAttributes.ContentState.early
    GroupActivityAttributes.ContentState.almostUnlocked
}
