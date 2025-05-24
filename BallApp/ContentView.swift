//
//  ContentView.swift
//  BallApp
//
//  Created by 蒋熹煜 on 2025/5/24.
//

import SwiftUI
import FirebaseFirestore

struct ContentView: View {
    @StateObject private var firebaseService = FirebaseService()
    @State private var matches: [Match] = []
    @State private var isLoading = false
    @State private var showingCreateMatch = false
    @State private var matchToDelete: Match? = nil
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            ZStack {
        VStack {
                    if matches.isEmpty && !isLoading {
                        VStack(spacing: 20) {
                            Image(systemName: "table.tennis.paddle.ball")
                                .font(.system(size: 64))
                                .foregroundColor(.blue)

                            Text("No Match Records")
                                .font(.title2)
                                .foregroundColor(.secondary)

                            Button(action: {
                                showingCreateMatch = true
                            }) {
                                Text("Create New Match")
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
                            ForEach(matches) { match in
                                NavigationLink(destination: MatchDetailView(match: match, firebaseService: firebaseService)) {
                                    MatchRowView(match: match)
                                        .contentShape(Rectangle())
                                        .contextMenu {
                                            Button(role: .destructive, action: {
                                                matchToDelete = match
                                                showingDeleteConfirmation = true
                                            }) {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .onLongPressGesture {
                                            matchToDelete = match
                                            showingDeleteConfirmation = true
                                        }
                                }
                            }
                            .onDelete(perform: deleteMatch)
                        }
                        .refreshable {
                            await loadMatches()
                        }
                    }
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Table Tennis Match Records")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateMatch = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateMatch) {
                CreateMatchView(firebaseService: firebaseService, onMatchCreated: { newMatch in
                    Task {
                        await loadMatches()
                    }
                })
            }
            .onAppear {
                Task {
                    await loadMatches()
                }
            }
            .alert("Confirm Delete", isPresented: $showingDeleteConfirmation, presenting: matchToDelete) { match in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let id = match.id {
                        Task {
                            do {
                                try await firebaseService.deleteMatch(id: id)
                                await loadMatches()
                            } catch {
                                print("Error deleting match: \(error)")
                            }
                        }
                    }
                }
            } message: { match in
                Text("Are you sure you want to delete match \"\(match.teamA) vs \(match.teamB)\"? This action cannot be undone.")
            }
        }
    }

    private func loadMatches() async {
        isLoading = true
        defer { isLoading = false }

        do {
            matches = try await firebaseService.getMatches()
        } catch {
            print("Error loading matches: \(error)")
        }
    }

    private func deleteMatch(at offsets: IndexSet) {
        Task {
            for index in offsets {
                if let id = matches[index].id {
                    do {
                        try await firebaseService.deleteMatch(id: id)
                        await loadMatches()
                    } catch {
                        print("Error deleting match: \(error)")
                    }
                }
            }
        }
    }
}

struct MatchRowView: View {
    let match: Match

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(match.teamA) vs \(match.teamB)")
                    .font(.headline)
                Spacer()
                Text("\(match.score.teamA) : \(match.score.teamB)")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .cornerRadius(4)
            }

            HStack {
                statusView
                Spacer()
                Text(formatDate(match.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusView: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var statusColor: Color {
        switch match.status {
        case .created:
            return .yellow
        case .inProgress:
            return .green
        case .finished:
            return .blue
        }
    }

    private var statusText: String {
        switch match.status {
        case .created:
            return "Pending"
        case .inProgress:
            return "In Progress"
        case .finished:
            return "Completed"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
