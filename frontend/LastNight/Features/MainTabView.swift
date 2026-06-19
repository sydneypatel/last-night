import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            GroupsView()
                .tabItem {
                    Label("groups", systemImage: "person.3.fill")
                }

            LibraryView()
                .tabItem {
                    Label("library", systemImage: "photo.stack.fill")
                }

            SearchView()
                .tabItem {
                    Label("search", systemImage: "magnifyingglass")
                }

            ProfileView()
                .tabItem {
                    Label("profile", systemImage: "person.fill")
                }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}
