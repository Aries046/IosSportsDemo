//
//  CreateMatchView.swift
//  BallApp
//
//  Created by Cursor AI on 2025/5/24.
//

import SwiftUI

struct CreateMatchView: View {
    @Environment(\.dismiss) private var dismiss

    let firebaseService: FirebaseService
    let onMatchCreated: (Match) -> Void

    @State private var teamA = ""
    @State private var teamB = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Teams")) {
                    TextField("Team A Name", text: $teamA)
                        .autocapitalization(.words)
                    TextField("Team B Name", text: $teamB)
                        .autocapitalization(.words)
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: createMatch) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Create Match")
                        }
                    }
                    .disabled(teamA.isEmpty || teamB.isEmpty || isLoading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Create New Match")
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

    private func createMatch() {
        guard !teamA.isEmpty, !teamB.isEmpty else {
            errorMessage = "Please enter names for both teams"
            return
        }

        isLoading = true
        errorMessage = nil

        let newMatch = firebaseService.createMatch(teamA: teamA, teamB: teamB)

        Task {
            do {
                let id = try await firebaseService.saveMatch(newMatch)
                var savedMatch = newMatch
                savedMatch.id = id
                DispatchQueue.main.async {
                    isLoading = false
                    onMatchCreated(savedMatch)
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to create match: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    CreateMatchView(firebaseService: FirebaseService(), onMatchCreated: { _ in })
}