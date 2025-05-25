import SwiftUI

struct AddPlayerToTeamView: View {
    let firebaseService: FirebaseService
    let teamId: String
    let teamPlayers: [PlayerProfile]
    let onPlayerAdded: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var allPlayers: [PlayerProfile] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var filteredPlayers: [PlayerProfile] {
        if searchText.isEmpty {
            return allPlayers.filter { player in
                !teamPlayers.contains { $0.id == player.id }
            }
        } else {
            return allPlayers.filter { player in
                !teamPlayers.contains { $0.id == player.id } &&
                player.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if filteredPlayers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text(searchText.isEmpty ? "No Available Players" : "No Players Found")
                            .font(.headline)
                            .foregroundColor(.gray)

                        if !searchText.isEmpty {
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            Text("You can add new players from the Players tab")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .padding(.top, 50)
                } else {
                    List {
                        ForEach(filteredPlayers) { player in
                            Button(action: {
                                addPlayerToTeam(player)
                            }) {
                                HStack(spacing: 12) {
                                    // Player avatar
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
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.gray.opacity(0.3))
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(player.name)
                                            .font(.headline)

                                        Text(player.position)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .navigationTitle("Add Players")
            .searchable(text: $searchText, prompt: "Search players")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
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
                loadPlayers()
            }
        }
    }

    private func loadPlayers() {
        isLoading = true

        Task {
            do {
                allPlayers = try await firebaseService.getPlayerProfiles()
                DispatchQueue.main.async {
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to load players: \(error.localizedDescription)"
                }
            }
        }
    }

    private func addPlayerToTeam(_ player: PlayerProfile) {
        guard let playerId = player.id else { return }

        isLoading = true

        Task {
            do {
                try await firebaseService.addPlayerToTeam(teamId: teamId, playerId: playerId)

                LocalDataStore.shared.addPlayerToTeam(playerId: playerId, teamId: teamId)

                DispatchQueue.main.async {
                    isLoading = false
                    onPlayerAdded()
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to add player: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    AddPlayerToTeamView(
        firebaseService: FirebaseService(),
        teamId: "preview",
        teamPlayers: [],
        onPlayerAdded: {}
    )
}
