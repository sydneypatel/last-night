import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

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
        .onChange(of: appState.pendingFollowUserId) { newValue in
            guard newValue != nil else { return }
            selectedTab = 2
        }
    }
}
