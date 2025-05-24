//
//  AddPlayerView.swift
//  BallApp
//
//  Created by Cursor AI on 2025/5/24.
//

import SwiftUI

struct AddPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    let firebaseService: FirebaseService
    let matchId: String
    let teamName: String
    let isTeamA: Bool
    let onPlayerAdded: () -> Void

    @State private var playerName = ""
    @State private var playerPosition = "Attacker"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let positions = ["Attacker", "Defender", "All-round", "Chopper", "Blocker"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add Player to \(teamName)")) {
                    TextField("Player Name", text: $playerName)
                        .autocapitalization(.words)

                    Picker("Position", selection: $playerPosition) {
                        ForEach(positions, id: \.self) { position in
                            Text(position).tag(position)
                        }
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: addPlayer) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Add Player")
                        }
                    }
                    .disabled(playerName.isEmpty || isLoading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Add Player")
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

    private func addPlayer() {
        guard !playerName.isEmpty else {
            errorMessage = "Please enter player name"
            return
        }

        isLoading = true
        errorMessage = nil

        let player = Player(name: playerName, position: playerPosition)

        Task {
            do {
                try await firebaseService.addPlayer(to: matchId, player: player, isTeamA: isTeamA)
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
    AddPlayerView(
        firebaseService: FirebaseService(),
        matchId: "preview",
        teamName: "Team A",
        isTeamA: true,
        onPlayerAdded: {}
    )
}