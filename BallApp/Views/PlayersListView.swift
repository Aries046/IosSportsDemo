import SwiftUI

struct PlayersListView: View {
    @StateObject private var firebaseService = FirebaseService()
    @State private var players: [PlayerProfile] = []
    @State private var isLoading = false
    @State private var showingAddPlayer = false
    @State private var errorMessage: String?
    @State private var searchText = ""

    var filteredPlayers: [PlayerProfile] {
        if searchText.isEmpty {
            return players
        } else {
            return players.filter { player in
                player.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if players.isEmpty && !isLoading {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)

                        Text("No Players")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Button(action: {
                            showingAddPlayer = true
                        }) {
                            Text("Add New Player")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredPlayers) { player in
                            NavigationLink(destination: PlayerDetailView(player: player, firebaseService: firebaseService)) {
                                PlayerRowView(player: player)
                            }
                        }
                        .onDelete(perform: deletePlayers)
                    }
                    .refreshable {
                        await loadPlayers()
                    }
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Players")
            .searchable(text: $searchText, prompt: "Search by name")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddPlayer = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlayer) {
                PlayerProfileEditView(firebaseService: firebaseService, onPlayerSaved: { _ in
                    Task {
                        await loadPlayers()
                    }
                })
            }
            .alert(isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                Task {
                    await loadPlayers()
                }
            }
        }
    }

    private func loadPlayers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            players = try await firebaseService.getPlayerProfiles()
        } catch {
            errorMessage = "Failed to load players: \(error.localizedDescription)"
        }
    }

    private func deletePlayers(at offsets: IndexSet) {
        Task {
            for index in offsets {
                if let id = filteredPlayers[index].id {
                    do {
                        try await firebaseService.deletePlayerProfile(id: id)
                    } catch {
                        errorMessage = "Failed to delete player: \(error.localizedDescription)"
                    }
                }
            }

            await loadPlayers()
        }
    }
}

struct PlayerRowView: View {
    let player: PlayerProfile

    var body: some View {
        HStack(spacing: 12) {
            // Avatar image
            if let avatarURL = player.avatarURL, !avatarURL.isEmpty {
                AsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray.opacity(0.3))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.headline)

                HStack {
                    Text(player.position)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let nationality = player.nationality, !nationality.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(nationality)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("Matches: \(player.stats.totalMatches)")
                    .font(.caption)
                    .foregroundColor(.blue)

                if player.stats.totalMatches > 0 {
                    Text("Win rate: \(Int(player.stats.winRate * 100))%")
                        .font(.caption)
                        .foregroundColor(player.stats.winRate >= 0.5 ? .green : .orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PlayersListView()
}