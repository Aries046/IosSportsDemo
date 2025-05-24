//
//  FirebaseService.swift
//  BallApp
//
//  Created by Cursor AI on 2025/5/24.
//

import Foundation
import FirebaseFirestore
import Combine

class FirebaseService: ObservableObject {
    private let db = Firestore.firestore()

    // MARK: - Matches

    func createMatch(teamA: String, teamB: String) -> Match {
        let match = Match(
            teamA: teamA,
            teamB: teamB,
            playersA: [],
            playersB: [],
            score: Score(teamA: 0, teamB: 0),
            events: [],
            status: .created,
            createdAt: Date()
        )

        return match
    }

    func saveMatch(_ match: Match) async throws -> String {
        if let id = match.id {
            try await db.collection("matches").document(id).setData(from: match)
            return id
        } else {
            let docRef = try db.collection("matches").addDocument(from: match)
            return docRef.documentID
        }
    }

    func getMatch(id: String) async throws -> Match {
        let docRef = db.collection("matches").document(id)
        let document = try await docRef.getDocument()

        guard let match = try? document.data(as: Match.self) else {
            throw NSError(domain: "FirebaseError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Match not found"])
        }

        return match
    }

    func getMatches() async throws -> [Match] {
        let querySnapshot = try await db.collection("matches").order(by: "createdAt", descending: true).getDocuments()

        return querySnapshot.documents.compactMap { document in
            try? document.data(as: Match.self)
        }
    }

    func updateMatchStatus(matchId: String, status: MatchStatus) async throws {
        try await db.collection("matches").document(matchId).updateData(["status": status.rawValue])
    }

    func deleteMatch(id: String) async throws {
        try await db.collection("matches").document(id).delete()
    }

    // MARK: - Players

    func addPlayer(to matchId: String, player: Player, isTeamA: Bool) async throws {
        let match = try await getMatch(id: matchId)
        var updatedMatch = match

        if isTeamA {
            updatedMatch.playersA.append(player)
        } else {
            updatedMatch.playersB.append(player)
        }

        try await db.collection("matches").document(matchId).setData(from: updatedMatch)
    }

    func removePlayer(from matchId: String, playerId: String, isTeamA: Bool) async throws {
        let match = try await getMatch(id: matchId)
        var updatedMatch = match

        if isTeamA {
            updatedMatch.playersA.removeAll { $0.id == playerId }
        } else {
            updatedMatch.playersB.removeAll { $0.id == playerId }
        }

        try await db.collection("matches").document(matchId).setData(from: updatedMatch)
    }

    // MARK: - Events

    func addEvent(to matchId: String, event: MatchEvent) async throws {
        let match = try await getMatch(id: matchId)
        var updatedMatch = match
        var updatedEvent = event

        // Auto-generate ID if not provided
        if updatedEvent.id == nil {
            updatedEvent.id = UUID().uuidString
        }

        updatedMatch.events.append(updatedEvent)

        // Check if this is a score point event
        if event.type == .scorePoint {
            // Update score
            if event.teamId == match.teamA {
                updatedMatch.score.teamA += 1
            } else if event.teamId == match.teamB {
                updatedMatch.score.teamB += 1
            }
        }

        try await db.collection("matches").document(matchId).setData(from: updatedMatch)
    }

    // MARK: - Rule validation

    func validateServeBeforeHit(match: Match) -> Bool {
        // Rule 1: Only allow hit actions after a serve

        // If no events yet, no validation needed
        if match.events.isEmpty {
            return true
        }

        // Find the most recent serve event
        if let lastServeIndex = match.events.lastIndex(where: { $0.type == .serve }) {
            // Check if there was any hit after the serve
            let eventsAfterServe = match.events.suffix(from: lastServeIndex + 1)
            return eventsAfterServe.contains(where: { $0.type == .spike || $0.type == .block })
        }

        return false
    }

    func validateScoreAfterHit(match: Match) -> Bool {
        // Rule 2: Score can only happen after a hit

        // If no events or only one event, no validation needed
        if match.events.count <= 1 {
            return true
        }

        // Check if the last event is a score
        if match.events.last?.type == .scorePoint {
            // Get the event before the score
            let previousEvent = match.events[match.events.count - 2]
            // Check if it was a hit (spike or block)
            return previousEvent.type == .spike || previousEvent.type == .block
        }

        return true
    }
}