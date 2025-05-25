import SwiftUI

struct MainTabView: View {
    @StateObject private var firebaseService = FirebaseService()

    var body: some View {
        TabView {
            // Matches Tab
            ContentView()
                .tabItem {
                    Label("Matches", systemImage: "trophy")
                }

            // Players Tab
            PlayersListView()
                .tabItem {
                    Label("Players", systemImage: "person.2")
                }

            // Teams Tab
            TeamsListView()
                .tabItem {
                    Label("Teams", systemImage: "person.3")
                }
        }
    }
}

#Preview {
    MainTabView()
}
