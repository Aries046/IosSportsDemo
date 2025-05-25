import Foundation
import FirebaseFirestore

struct PlayerProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var position: String
    var age: Int?
    var nationality: String?
    var avatarURL: String?
    var bio: String?
    var stats: PlayerStats
    var createdAt: Date

    init(id: String? = nil, name: String, position: String, age: Int? = nil,
         nationality: String? = nil, avatarURL: String? = nil, bio: String? = nil,
         stats: PlayerStats = PlayerStats(), createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.position = position
        self.age = age
        self.nationality = nationality
        self.avatarURL = avatarURL
        self.bio = bio
        self.stats = stats
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case position
        case age
        case nationality
        case avatarURL
        case bio
        case stats
        case createdAt
    }
}

struct PlayerStats: Codable {
    var totalMatches: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var serveCount: Int = 0
    var forehandCount: Int = 0
    var backhandCount: Int = 0
    var scoreCount: Int = 0
    var errorCount: Int = 0

    var winRate: Double {
        if totalMatches == 0 {
            return 0.0
        }
        return Double(wins) / Double(totalMatches)
    }
}