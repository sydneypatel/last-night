//
//  LastNightWidgetsLiveActivity.swift
//  LastNightWidgets
//
//  Created by Sydney Patel on 7/17/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LastNightWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LastNightWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LastNightWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LastNightWidgetsAttributes {
    fileprivate static var preview: LastNightWidgetsAttributes {
        LastNightWidgetsAttributes(name: "World")
    }
}

extension LastNightWidgetsAttributes.ContentState {
    fileprivate static var smiley: LastNightWidgetsAttributes.ContentState {
        LastNightWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LastNightWidgetsAttributes.ContentState {
         LastNightWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LastNightWidgetsAttributes.preview) {
   LastNightWidgetsLiveActivity()
} contentStates: {
    LastNightWidgetsAttributes.ContentState.smiley
    LastNightWidgetsAttributes.ContentState.starEyes
}
