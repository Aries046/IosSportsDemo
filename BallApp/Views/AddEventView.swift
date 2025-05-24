//
//  AddEventView.swift
//  BallApp
//
//  Created by Cursor AI on 2025/5/24.
//

import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss

    let firebaseService: FirebaseService
    let match: Match
    let onEventAdded: () -> Void

    @State private var selectedPlayer: Player?
    @State private var selectedTeam: String = ""
    @State private var selectedEventType: EventType = .serve
    @State private var description: String = ""
    @State private var isTeamA: Bool = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var validationError: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Team")) {
                    Picker("Team", selection: $isTeamA) {
                        Text(match.teamA).tag(true)
                        Text(match.teamB).tag(false)
                    }
                    .onChange(of: isTeamA) { newValue in
                        selectedTeam = newValue ? match.teamA : match.teamB
                        selectedPlayer = nil
                    }
                    .onAppear {
                        selectedTeam = isTeamA ? match.teamA : match.teamB
                    }
                }

                Section(header: Text("Select Player")) {
                    if availablePlayers.isEmpty {
                        Text("No available players")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Player", selection: $selectedPlayer) {
                            Text("Please select a player").tag(nil as Player?)
                            ForEach(availablePlayers) { player in
                                Text(player.name).tag(player as Player?)
                            }
                        }
                    }
                }

                Section(header: Text("Action Type")) {
                    Picker("Action", selection: $selectedEventType) {
                        Text("Serve").tag(EventType.serve)
                        Text("Spike").tag(EventType.spike)
                        Text("Block").tag(EventType.block)
                        Text("Score").tag(EventType.scorePoint)
                        Text("Error").tag(EventType.error)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Notes")) {
                    TextField("Optional", text: $description)
                        .autocapitalization(.sentences)
                }

                if let validationError = validationError {
                    Section {
                        Text(validationError)
                            .foregroundColor(.red)
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: addEvent) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Record Action")
                        }
                    }
                    .disabled(selectedPlayer == nil || isLoading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Record Match Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var availablePlayers: [Player] {
        isTeamA ? match.playersA : match.playersB
    }

    private func addEvent() {
        guard let player = selectedPlayer else {
            validationError = "Please select a player"
            return
        }

        // Validate rules
        if selectedEventType == .spike || selectedEventType == .block {
            if !validateHitAction() {
                validationError = "There must be a serve action before recording a hit"
                return
            }
        }

        if selectedEventType == .scorePoint {
            if !validateScoreAction() {
                validationError = "A score can only be recorded after a hit action"
                return
            }
        }

        validationError = nil
        isLoading = true
        errorMessage = nil

        let event = MatchEvent(
            type: selectedEventType,
            playerId: player.id ?? UUID().uuidString,
            playerName: player.name,
            teamId: isTeamA ? match.teamA : match.teamB,
            timestamp: Date(),
            description: description
        )

        Task {
            do {
                if let id = match.id {
                    try await firebaseService.addEvent(to: id, event: event)
                    DispatchQueue.main.async {
                        isLoading = false
                        onEventAdded()
                        dismiss()
                    }
                } else {
                    throw NSError(domain: "EventError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid match ID"])
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to add event: \(error.localizedDescription)"
                }
            }
        }
    }

    private func validateHitAction() -> Bool {
        // Rule 1: Only allow hit actions after a serve
        if match.events.isEmpty {
            return false
        }

        // Check if there is a serve action
        return match.events.contains(where: { $0.type == .serve })
    }

    private func validateScoreAction() -> Bool {
        // Rule 2: Score can only happen after a hit
        if match.events.isEmpty {
            return false
        }

        // Find the last action
        if let lastEvent = match.events.last {
            // Check if the last action was a hit
            return lastEvent.type == .spike || lastEvent.type == .block
        }

        return false
    }
}

#Preview {
    AddEventView(
        firebaseService: FirebaseService(),
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
            score: Score(teamA: 0, teamB: 0),
            events: [],
            status: .inProgress,
            createdAt: Date()
        ),
        onEventAdded: {}
    )
}