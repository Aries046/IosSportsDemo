//
//  MatchDetailView.swift
//  BallApp
//
//  Created by Cursor AI on 2025/5/24.
//

import SwiftUI

struct MatchDetailView: View {
    @State var match: Match
    let firebaseService: FirebaseService

    @State private var showingAddPlayer = false
    @State private var showingAddEvent = false
    @State private var selectedTeamForPlayer: Bool = true // true for teamA, false for teamB
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Scoreboard
                scoreboardSection

                // Status controls
                matchStatusSection

                // Player lists
                playersSection

                // Match action records
                eventsSection
            }
            .padding()
        }
        .navigationTitle("\(match.teamA) vs \(match.teamB)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if match.status == .inProgress {
                    Button(action: {
                        showingAddEvent = true
                    }) {
                        Image(systemName: "plus.circle")
                    }
                    .disabled(match.playersA.isEmpty || match.playersB.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(
                firebaseService: firebaseService,
                matchId: match.id ?? "",
                teamName: selectedTeamForPlayer ? match.teamA : match.teamB,
                isTeamA: selectedTeamForPlayer,
                onPlayerAdded: { refreshMatch() }
            )
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(
                firebaseService: firebaseService,
                match: match,
                onEventAdded: { refreshMatch() }
            )
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
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                .ignoresSafeArea()
            }
        }
    }

    private var scoreboardSection: some View {
        VStack {
            Text("Score")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)

            HStack(alignment: .top, spacing: 20) {
                VStack {
                    Text(match.teamA)
                        .font(.headline)
                    Text("\(match.score.teamA)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text(match.teamB)
                        .font(.headline)
                    Text("\(match.score.teamB)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private var matchStatusSection: some View {
        VStack {
            Text("Match Status")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)

            HStack(spacing: 20) {
                switch match.status {
                case .created:
                    Button(action: startMatch) {
                        Label("Start Match", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(match.playersA.count < 2 || match.playersB.count < 2)

                case .inProgress:
                    Button(action: endMatch) {
                        Label("End Match", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                case .finished:
                    Text("Match Completed")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }

    private var playersSection: some View {
        VStack {
            Text("Players")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)

            HStack(alignment: .top, spacing: 20) {
                // Team A Players
                VStack(alignment: .leading) {
                    HStack {
                        Text(match.teamA)
                            .font(.headline)
                        Spacer()
                        if match.status == .created {
                            Button(action: {
                                selectedTeamForPlayer = true
                                showingAddPlayer = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    if match.playersA.isEmpty {
                        Text("No players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(match.playersA) { player in
                            PlayerRow(player: player)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                // Team B Players
                VStack(alignment: .leading) {
                    HStack {
                        Text(match.teamB)
                            .font(.headline)
                        Spacer()
                        if match.status == .created {
                            Button(action: {
                                selectedTeamForPlayer = false
                                showingAddPlayer = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    if match.playersB.isEmpty {
                        Text("No players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(match.playersB) { player in
                            PlayerRow(player: player)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private var eventsSection: some View {
        VStack {
            Text("Match Records")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)

            if match.events.isEmpty {
                Text("No match records yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(match.events.sorted { $0.timestamp > $1.timestamp }) { event in
                        EventRow(event: event, teamA: match.teamA, teamB: match.teamB)
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private func startMatch() {
        guard match.playersA.count >= 2 && match.playersB.count >= 2 else {
            errorMessage = "Each team needs at least 2 players to start the match"
            return
        }

        updateMatchStatus(.inProgress)
    }

    private func endMatch() {
        updateMatchStatus(.finished)
    }

    private func updateMatchStatus(_ status: MatchStatus) {
        guard let id = match.id else {
            errorMessage = "Invalid match ID"
            return
        }

        isLoading = true

        Task {
            do {
                try await firebaseService.updateMatchStatus(matchId: id, status: status)
                await refreshMatch()
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to update match status: \(error.localizedDescription)"
                }
            }
        }
    }

    private func refreshMatch() {
        guard let id = match.id else { return }

        isLoading = true

        Task {
            do {
                let updatedMatch = try await firebaseService.getMatch(id: id)
                DispatchQueue.main.async {
                    self.match = updatedMatch
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to get match information: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct PlayerRow: View {
    let player: Player

    var body: some View {
        HStack {
            Text(player.name)
                .font(.subheadline)
            Spacer()
            Text(player.position)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct EventRow: View {
    let event: MatchEvent
    let teamA: String
    let teamB: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(event.playerName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(actionText)
                    .font(.caption)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(teamText)
                    .font(.caption)
                    .foregroundColor(teamColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(teamColor.opacity(0.1))
                    .cornerRadius(4)

                Text(timeText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }

    private var actionText: String {
        switch event.type {
        case .serve:
            return "Serve"
        case .spike:
            return "Spike"
        case .block:
            return "Block"
        case .scorePoint:
            return "Score"
        case .error:
            return "Error"
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: event.timestamp)
    }

    private var teamText: String {
        return event.teamId == teamA ? teamA : teamB
    }

    private var teamColor: Color {
        return event.teamId == teamA ? .blue : .red
    }
}

#Preview {
    NavigationView {
        MatchDetailView(
            match: Match(
                id: "preview",
                teamA: "Team A",
                teamB: "Team B",
                playersA: [
                    Player(id: "1", name: "John Smith", position: "Setter"),
                    Player(id: "2", name: "Mike Johnson", position: "Middle Blocker")
                ],
                playersB: [
                    Player(id: "3", name: "David Brown", position: "Outside Hitter"),
                    Player(id: "4", name: "James Wilson", position: "Libero")
                ],
                score: Score(teamA: 5, teamB: 3),
                events: [],
                status: .inProgress,
                createdAt: Date()
            ),
            firebaseService: FirebaseService()
        )
    }
}