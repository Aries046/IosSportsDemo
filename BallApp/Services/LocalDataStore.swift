import Foundation
import UIKit

class LocalDataStore {
    static let shared = LocalDataStore()

    private let fileManager = FileManager.default
    private let documentsDirectory: URL

    // 存储玩家头像的目录
    private let playerAvatarsDirectory: URL

    // 存储队伍Logo的目录
    private let teamLogosDirectory: URL

    // 本地数据存储键
    private enum StoreKeys {
        static let playerTeamBindings = "playerTeamBindings"
    }

    private init() {
        // 获取应用Documents目录
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // 创建头像存储目录
        playerAvatarsDirectory = documentsDirectory.appendingPathComponent("PlayerAvatars")
        teamLogosDirectory = documentsDirectory.appendingPathComponent("TeamLogos")

        // 确保目录存在
        try? fileManager.createDirectory(at: playerAvatarsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: teamLogosDirectory, withIntermediateDirectories: true)
    }

    // MARK: - 玩家头像管理

    /// 保存玩家头像到本地文件系统
    /// - Parameters:
    ///   - imageData: 头像图片数据
    ///   - playerId: 玩家ID
    /// - Returns: 本地文件URL字符串
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

    /// 根据URL加载玩家头像
    /// - Parameter urlString: 头像URL字符串
    /// - Returns: 头像UIImage对象
    func loadPlayerAvatar(from urlString: String) -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        if url.isFileURL {
            // 如果是本地文件URL，直接从文件系统加载
            do {
                let imageData = try Data(contentsOf: url)
                return UIImage(data: imageData)
            } catch {
                print("Error loading avatar from file: \(error)")
                return nil
            }
        } else {
            // 如果是远程URL，这里可以添加缓存逻辑
            // 这个演示中，我们暂不实现远程缓存
            return nil
        }
    }

    // MARK: - 队伍Logo管理

    /// 保存队伍Logo到本地文件系统
    /// - Parameters:
    ///   - imageData: Logo图片数据
    ///   - teamId: 队伍ID
    /// - Returns: 本地文件URL字符串
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

    /// 根据URL加载队伍Logo
    /// - Parameter urlString: Logo URL字符串
    /// - Returns: Logo UIImage对象
    func loadTeamLogo(from urlString: String) -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        if url.isFileURL {
            // 如果是本地文件URL，直接从文件系统加载
            do {
                let imageData = try Data(contentsOf: url)
                return UIImage(data: imageData)
            } catch {
                print("Error loading logo from file: \(error)")
                return nil
            }
        } else {
            // 如果是远程URL，这里可以添加缓存逻辑
            // 这个演示中，我们暂不实现远程缓存
            return nil
        }
    }

    // MARK: - 玩家和队伍绑定管理

    /// 将玩家添加到队伍
    /// - Parameters:
    ///   - playerId: 玩家ID
    ///   - teamId: 队伍ID
    func addPlayerToTeam(playerId: String, teamId: String) {
        var bindings = getPlayerTeamBindings()
        bindings[playerId] = teamId
        savePlayerTeamBindings(bindings)
    }

    /// 从队伍中移除玩家
    /// - Parameters:
    ///   - playerId: 玩家ID
    ///   - teamId: 队伍ID（用于验证）
    func removePlayerFromTeam(playerId: String, teamId: String) {
        var bindings = getPlayerTeamBindings()
        // 只有当玩家确实属于该队伍时才移除
        if bindings[playerId] == teamId {
            bindings.removeValue(forKey: playerId)
            savePlayerTeamBindings(bindings)
        }
    }

    /// 获取队伍中的所有玩家ID
    /// - Parameter teamId: 队伍ID
    /// - Returns: 玩家ID数组
    func getTeamPlayerIds(teamId: String) -> [String] {
        let bindings = getPlayerTeamBindings()
        return bindings.filter { $0.value == teamId }.map { $0.key }
    }

    /// 获取玩家所属的队伍ID
    /// - Parameter playerId: 玩家ID
    /// - Returns: 队伍ID，如果不属于任何队伍则返回nil
    func getPlayerTeamId(playerId: String) -> String? {
        return getPlayerTeamBindings()[playerId]
    }

    // MARK: - 私有辅助方法

    /// 获取玩家-队伍绑定关系
    private func getPlayerTeamBindings() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: StoreKeys.playerTeamBindings),
              let bindings = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return bindings
    }

    /// 保存玩家-队伍绑定关系
    private func savePlayerTeamBindings(_ bindings: [String: String]) {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: StoreKeys.playerTeamBindings)
        }
    }

    /// 清理本地过期的头像和Logo文件
    func cleanupOldImages() {
        // 这里可以实现一个简单的清理逻辑，删除不再使用的图片文件
        // 本演示中省略实现
    }
}