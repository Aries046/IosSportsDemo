

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

        print("Retrieved match data from database: TeamA players=\(match.playersA.map { $0.name }), TeamB players=\(match.playersB.map { $0.name })")
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

    func addPlayer(to matchId: String, player: Player, isTeamA: Bool) async throws -> Player {
        let match = try await getMatch(id: matchId)
        var updatedMatch = match

        // Create a player with ID if it doesn't have one
        var updatedPlayer = player

        // 强制生成新的唯一ID，确保不使用现有ID
        updatedPlayer.id = UUID().uuidString

        print("Adding player: \(updatedPlayer.name), position: \(updatedPlayer.position), ID: \(updatedPlayer.id ?? "none")")

        if isTeamA {
            updatedMatch.playersA.append(updatedPlayer)
        } else {
            updatedMatch.playersB.append(updatedPlayer)
        }

        try await db.collection("matches").document(matchId).setData(from: updatedMatch)

        // 打印更新后的球员列表和ID
        print("Updated player list: TeamA=\(updatedMatch.playersA.map { "\($0.name)" })")
        print("Updated player list: TeamB=\(updatedMatch.playersB.map { "\($0.name)" })")

        // Return the updated player with ID
        return updatedPlayer
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
            return eventsAfterServe.contains(where: { $0.type == .forehand || $0.type == .backhand })
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
            // Check if it was a hit (forehand or backhand)
            return previousEvent.type == .forehand || previousEvent.type == .backhand
        }

        return true
    }

    // MARK: - Player Profiles

    func getPlayerProfiles() async throws -> [PlayerProfile] {
        let querySnapshot = try await db.collection("playerProfiles")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return querySnapshot.documents.compactMap { document in
            try? document.data(as: PlayerProfile.self)
        }
    }

    func getPlayerProfile(id: String) async throws -> PlayerProfile? {
        let docRef = db.collection("playerProfiles").document(id)
        let document = try await docRef.getDocument()

        return try? document.data(as: PlayerProfile.self)
    }

    func savePlayerProfile(_ profile: PlayerProfile) async throws -> String {
        if let id = profile.id {
            try await db.collection("playerProfiles").document(id).setData(from: profile)
            return id
        } else {
            let docRef = try db.collection("playerProfiles").addDocument(from: profile)
            return docRef.documentID
        }
    }

    func updatePlayerAvatar(playerId: String, imageData: Data) async throws -> String {
        // 使用本地存储保存头像
        guard let avatarURL = LocalDataStore.shared.savePlayerAvatar(imageData: imageData, playerId: playerId) else {
            throw NSError(domain: "LocalStorageError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to save avatar locally"])
        }

        // 更新玩家资料中的头像URL
        if let profile = try await getPlayerProfile(id: playerId) {
            var updatedProfile = profile
            updatedProfile.avatarURL = avatarURL
            try await savePlayerProfile(updatedProfile)
        }

        return avatarURL
    }

    func deletePlayerProfile(id: String) async throws {
        try await db.collection("playerProfiles").document(id).delete()
    }

    // Convert from Player to PlayerProfile
    func createProfileFromPlayer(_ player: Player) -> PlayerProfile {
        return PlayerProfile(
            id: player.id,
            name: player.name,
            position: player.position
        )
    }

    // MARK: - Teams

    func getTeams() async throws -> [Team] {
        let querySnapshot = try await db.collection("teams")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return querySnapshot.documents.compactMap { document in
            try? document.data(as: Team.self)
        }
    }

    func getTeam(id: String) async throws -> Team? {
        let docRef = db.collection("teams").document(id)
        let document = try await docRef.getDocument()

        return try? document.data(as: Team.self)
    }

    func saveTeam(_ team: Team) async throws -> String {
        if let id = team.id {
            try await db.collection("teams").document(id).setData(from: team)
            return id
        } else {
            let docRef = try db.collection("teams").addDocument(from: team)
            return docRef.documentID
        }
    }

    func updateTeamLogo(teamId: String, imageData: Data) async throws -> String {
        // 使用本地存储保存Logo
        guard let logoURL = LocalDataStore.shared.saveTeamLogo(imageData: imageData, teamId: teamId) else {
            throw NSError(domain: "LocalStorageError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to save logo locally"])
        }

        // 更新团队资料中的Logo URL
        if let team = try await getTeam(id: teamId) {
            var updatedTeam = team
            updatedTeam.logo = logoURL
            try await saveTeam(updatedTeam)
        }

        return logoURL
    }

    func deleteTeam(id: String) async throws {
        try await db.collection("teams").document(id).delete()
    }

    func addPlayerToTeam(teamId: String, playerId: String) async throws {
        // 将队员添加到本地存储
        LocalDataStore.shared.addPlayerToTeam(playerId: playerId, teamId: teamId)

        // 更新Firebase中的Team数据，但只更新playerIds字段
        if let team = try await getTeam(id: teamId) {
            // 使用本地存储中的playerIds来更新Team
            let playerIds = LocalDataStore.shared.getTeamPlayerIds(teamId: teamId)

            // 合并本地存储和Firebase中的playerIds，避免覆盖Firebase中已有的ID
            var updatedTeam = team
            let allPlayerIds = Set(updatedTeam.playerIds).union(playerIds)
            updatedTeam.playerIds = Array(allPlayerIds)

            try await saveTeam(updatedTeam)
        }
    }

    func removePlayerFromTeam(teamId: String, playerId: String) async throws {
        // 从本地存储中移除队员
        LocalDataStore.shared.removePlayerFromTeam(playerId: playerId, teamId: teamId)

        // 从Firebase中更新Team数据
        if let team = try await getTeam(id: teamId) {
            // 获取本地存储中剩余的playerIds
            let remainingPlayerIds = LocalDataStore.shared.getTeamPlayerIds(teamId: teamId)

            var updatedTeam = team
            // 移除指定的玩家ID
            updatedTeam.playerIds.removeAll { $0 == playerId }
            // 确保本地存储中的IDs也包含在内
            updatedTeam.playerIds = Array(Set(updatedTeam.playerIds).union(remainingPlayerIds))

            try await saveTeam(updatedTeam)
        }
    }

    func getTeamPlayers(teamId: String) async throws -> [PlayerProfile] {
        // 首先从本地存储获取团队玩家IDs
        let localPlayerIds = LocalDataStore.shared.getTeamPlayerIds(teamId: teamId)

        // 再获取Firebase中存储的Team数据
        var allPlayerIds = localPlayerIds
        if let team = try await getTeam(id: teamId) {
            // 合并本地和远程的玩家IDs
            allPlayerIds = Array(Set(allPlayerIds).union(team.playerIds))
        }

        // 获取所有玩家的详细信息
        var players: [PlayerProfile] = []
        for playerId in allPlayerIds {
            if let player = try await getPlayerProfile(id: playerId) {
                players.append(player)
            }
        }

        return players
    }

    func getTeamMatches(teamId: String) async throws -> [Match] {
        if let team = try await getTeam(id: teamId) {
            var matches: [Match] = []

            for matchId in team.matchIds {
                do {
                    let match = try await getMatch(id: matchId)
                    matches.append(match)
                } catch {
                    print("Error fetching match with ID \(matchId): \(error)")
                }
            }

            return matches
        }

        return []
    }
}
