import Foundation
import FirebaseFirestore

struct Team: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var logo: String?
    var description: String?
    var foundedDate: Date?
    var coach: String?
    var playerIds: [String]
    var matchIds: [String]
    var stats: TeamStats
    var createdAt: Date

    init(id: String? = nil, name: String, logo: String? = nil, description: String? = nil,
         foundedDate: Date? = nil, coach: String? = nil, playerIds: [String] = [],
         matchIds: [String] = [], stats: TeamStats = TeamStats(), createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.logo = logo
        self.description = description
        self.foundedDate = foundedDate
        self.coach = coach
        self.playerIds = playerIds
        self.matchIds = matchIds
        self.stats = stats
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case logo
        case description
        case foundedDate
        case coach
        case playerIds
        case matchIds
        case stats
        case createdAt
    }
}

struct TeamStats: Codable {
    var totalMatches: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var draws: Int = 0
    var totalPoints: Int = 0

    var winRate: Double {
        if totalMatches == 0 {
            return 0.0
        }
        return Double(wins) / Double(totalMatches)
    }
}