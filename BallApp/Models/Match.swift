//
//  Match.swift
//  BallApp
//
//  Created by Cursor AI on 2025/5/24.
//

import Foundation
import FirebaseFirestore

struct Match: Identifiable, Codable {
    @DocumentID var id: String?
    var teamA: String
    var teamB: String
    var playersA: [Player]
    var playersB: [Player]
    var score: Score
    var events: [MatchEvent]
    var status: MatchStatus
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case teamA
        case teamB
        case playersA
        case playersB
        case score
        case events
        case status
        case createdAt
    }
}

enum MatchStatus: String, Codable {
    case created
    case inProgress
    case finished
}

struct Score: Codable {
    var teamA: Int
    var teamB: Int
}

struct Player: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var position: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case position
    }

    // Since id may be nil, we need a custom Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(position)
    }

    static func == (lhs: Player, rhs: Player) -> Bool {
        // If both objects have an id, compare the ids
        if let lhsId = lhs.id, let rhsId = rhs.id {
            return lhsId == rhsId
        }
        // Otherwise compare all properties
        return lhs.name == rhs.name && lhs.position == rhs.position
    }
}

struct MatchEvent: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var type: EventType
    var playerId: String
    var playerName: String
    var teamId: String
    var timestamp: Date
    var description: String

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case playerId
        case playerName
        case teamId
        case timestamp
        case description
    }

    // Custom Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
        hasher.combine(playerId)
        hasher.combine(playerName)
        hasher.combine(teamId)
        hasher.combine(timestamp)
        hasher.combine(description)
    }

    static func == (lhs: MatchEvent, rhs: MatchEvent) -> Bool {
        // If both objects have an id, compare the ids
        if let lhsId = lhs.id, let rhsId = rhs.id {
            return lhsId == rhsId
        }
        // Otherwise compare key properties
        return lhs.type == rhs.type &&
               lhs.playerId == rhs.playerId &&
               lhs.teamId == rhs.teamId &&
               lhs.timestamp == rhs.timestamp
    }
}

enum EventType: String, Codable {
    case serve
    case spike
    case block
    case scorePoint
    case error
}