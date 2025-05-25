import SwiftUI

struct TeamsListView: View {
    @StateObject private var firebaseService = FirebaseService()
    @State private var teams: [Team] = []
    @State private var isLoading = false
    @State private var showingAddTeam = false
    @State private var errorMessage: String?
    @State private var searchText = ""

    var filteredTeams: [Team] {
        if searchText.isEmpty {
            return teams
        } else {
            return teams.filter { team in
                team.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if teams.isEmpty && !isLoading {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3.sequence")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)

                        Text("No Teams")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Button(action: {
                            showingAddTeam = true
                        }) {
                            Text("Add New Team")
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
                        ForEach(filteredTeams) { team in
                            NavigationLink(destination: TeamDetailView(team: team, firebaseService: firebaseService)) {
                                TeamRowView(team: team)
                            }
                        }
                        .onDelete(perform: deleteTeams)
                    }
                    .refreshable {
                        await loadTeams()
                    }
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Teams")
            .searchable(text: $searchText, prompt: "Search by team name")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddTeam = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTeam) {
                TeamEditView(firebaseService: firebaseService, onTeamSaved: { _ in
                    Task {
                        await loadTeams()
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
                    await loadTeams()
                }
            }
        }
    }

    private func loadTeams() async {
        isLoading = true
        defer { isLoading = false }

        do {
            teams = try await firebaseService.getTeams()
        } catch {
            errorMessage = "Failed to load teams: \(error.localizedDescription)"
        }
    }

    private func deleteTeams(at offsets: IndexSet) {
        Task {
            for index in offsets {
                if let id = filteredTeams[index].id {
                    do {
                        try await firebaseService.deleteTeam(id: id)
                    } catch {
                        errorMessage = "Failed to delete team: \(error.localizedDescription)"
                    }
                }
            }

            await loadTeams()
        }
    }
}

struct TeamRowView: View {
    let team: Team

    var body: some View {
        HStack(spacing: 12) {
            // 队伍Logo
            if let logoURL = team.logo, !logoURL.isEmpty {
                AsyncImage(url: URL(string: logoURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.3.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.3.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray.opacity(0.3))
                    .padding(5)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .font(.headline)

                if let coach = team.coach, !coach.isEmpty {
                    Text("Coach: \(coach)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("Players: \(team.playerIds.count)")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("Matches: \(team.stats.totalMatches)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TeamsListView()
}