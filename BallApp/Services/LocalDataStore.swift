import Foundation
import UIKit

class LocalDataStore {
    static let shared = LocalDataStore()

    private let fileManager = FileManager.default
    private let documentsDirectory: URL

    private let playerAvatarsDirectory: URL

    private let teamLogosDirectory: URL

    private enum StoreKeys {
        static let playerTeamBindings = "playerTeamBindings"
    }

    private init() {

        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        playerAvatarsDirectory = documentsDirectory.appendingPathComponent("PlayerAvatars")
        teamLogosDirectory = documentsDirectory.appendingPathComponent("TeamLogos")


        try? fileManager.createDirectory(at: playerAvatarsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: teamLogosDirectory, withIntermediateDirectories: true)
    }


    func savePlayerAvatar(imageData: Data, playerId: String) -> String? {
        let fileName = "player_\(playerId)_\(Date().timeIntervalSince1970).jpg"
        let fileURL = playerAvatarsDirectory.appendingPathComponent(fileName)

        do {
            try imageData.write(to: fileURL)
            return fileURL.absoluteString
        } catch {
            print("Error saving player avatar: \(error)")
            return nil
        }
    }


    func loadPlayerAvatar(from urlString: String) -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        if url.isFileURL {

            do {
                let imageData = try Data(contentsOf: url)
                return UIImage(data: imageData)
            } catch {
                print("Error loading avatar from file: \(error)")
                return nil
            }
        } else {

            return nil
        }
    }


    func saveTeamLogo(imageData: Data, teamId: String) -> String? {
        let fileName = "team_\(teamId)_\(Date().timeIntervalSince1970).jpg"
        let fileURL = teamLogosDirectory.appendingPathComponent(fileName)

        do {
            try imageData.write(to: fileURL)
            return fileURL.absoluteString
        } catch {
            print("Error saving team logo: \(error)")
            return nil
        }
    }


    func loadTeamLogo(from urlString: String) -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        if url.isFileURL {

            do {
                let imageData = try Data(contentsOf: url)
                return UIImage(data: imageData)
            } catch {
                print("Error loading logo from file: \(error)")
                return nil
            }
        } else {

            return nil
        }
    }


    func addPlayerToTeam(playerId: String, teamId: String) {
        var bindings = getPlayerTeamBindings()
        bindings[playerId] = teamId
        savePlayerTeamBindings(bindings)
    }


    func removePlayerFromTeam(playerId: String, teamId: String) {
        var bindings = getPlayerTeamBindings()

        if bindings[playerId] == teamId {
            bindings.removeValue(forKey: playerId)
            savePlayerTeamBindings(bindings)
        }
    }


    func getTeamPlayerIds(teamId: String) -> [String] {
        let bindings = getPlayerTeamBindings()
        return bindings.filter { $0.value == teamId }.map { $0.key }
    }


    func getPlayerTeamId(playerId: String) -> String? {
        return getPlayerTeamBindings()[playerId]
    }


    private func getPlayerTeamBindings() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: StoreKeys.playerTeamBindings),
              let bindings = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return bindings
    }


    private func savePlayerTeamBindings(_ bindings: [String: String]) {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: StoreKeys.playerTeamBindings)
        }
    }


    func cleanupOldImages() {

    }
}
