import SwiftUI

private struct IdentifiableGroupId: Identifiable {
    let id: String
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var cameraGroupId: IdentifiableGroupId?

    var body: some View {
        TabView(selection: $selectedTab) {
            GroupsView()
                .tabItem { Label("groups", systemImage: "person.3.fill") }
                .tag(0)

            LibraryView()
                .tabItem { Label("library", systemImage: "photo.stack.fill") }
                .tag(1)

            SearchView()
                .tabItem { Label("search", systemImage: "magnifyingglass") }
                .tag(2)

            ProfileView()
                .tabItem { Label("profile", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
        .onChange(of: appState.pendingFollowUserId) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = 2
        }
        .onChange(of: appState.pendingGroupId) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = 0
        }
        .onChange(of: appState.pendingAdminReport) { _, newValue in
            guard newValue else { return }
            selectedTab = 3
            appState.pendingAdminReport = false
        }
        .onChange(of: appState.pendingCameraGroupId) { _, newValue in
            guard let groupId = newValue else { return }
            selectedTab = 0
            cameraGroupId = IdentifiableGroupId(id: groupId)
            appState.pendingCameraGroupId = nil
        }
        .fullScreenCover(item: $cameraGroupId) { wrapped in
            CameraView(groupId: wrapped.id) { _ in
                cameraGroupId = nil
            }
        }
        .task {
            if appState.pendingFollowUserId != nil {
                selectedTab = 2
            } else if appState.pendingGroupId != nil {
                selectedTab = 0
            } else if let groupId = appState.pendingCameraGroupId {
                selectedTab = 0
                cameraGroupId = IdentifiableGroupId(id: groupId)
                appState.pendingCameraGroupId = nil
            }
        }
    }
}
