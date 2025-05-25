import SwiftUI
import PhotosUI

struct TeamDetailView: View {
    let team: Team
    let firebaseService: FirebaseService

    @State private var isLoading = false
    @State private var isEditing = false
    @State private var showingAddPlayer = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var logoImage: UIImage?
    @State private var teamPlayers: [PlayerProfile] = []
    @State private var teamMatches: [Match] = []
    @State private var errorMessage: String?
    @State private var activeTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // 顶部队伍信息
            teamHeaderSection
                .padding(.bottom)

            // 选项卡栏
            tabBarView

            // 选项卡内容
            TabView(selection: $activeTab) {
                // 队员标签页
                playersTabView
                    .tag(0)

                // 比赛标签页
                matchesTabView
                    .tag(1)

                // 统计标签页
                statsTabView
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Team Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isEditing = true
                }) {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            TeamEditView(
                firebaseService: firebaseService,
                team: team,
                logoImage: logoImage,
                onTeamSaved: { _ in
                    // 这里会刷新队伍数据
                }
            )
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerToTeamView(
                firebaseService: firebaseService,
                teamId: team.id ?? "",
                teamPlayers: teamPlayers,
                onPlayerAdded: {
                    Task {
                        await loadTeamPlayers()
                    }
                }
            )
        }
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
                .ignoresSafeArea()
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            if let logoURL = team.logo, !logoURL.isEmpty {
                loadLogo(from: logoURL)
            }

            Task {
                await loadTeamData()
            }
        }
    }

    private var teamHeaderSection: some View {
        VStack(spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
                // 队伍Logo
                Group {
                    if let logoImage = logoImage {
                        Image(uiImage: logoImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let logoURL = team.logo, !logoURL.isEmpty {
                        AsyncImage(url: URL(string: logoURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        Image(systemName: "person.3.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(25)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }
                .frame(width: 100, height: 100)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                .shadow(radius: 3)

                // 编辑按钮
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                }
                .onChange(of: selectedItem) { _ in
                    loadTransferable(from: selectedItem)
                }
            }

            Text(team.name)
                .font(.title)
                .fontWeight(.bold)

            if let coach = team.coach, !coach.isEmpty {
                Text("Coach: \(coach)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let foundedDate = team.foundedDate {
                Text("Founded: \(formattedDate(foundedDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                VStack {
                    Text("\(teamPlayers.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 30)

                VStack {
                    Text("\(team.stats.totalMatches)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Matches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 30)

                VStack {
                    Text("\(team.stats.wins)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Wins")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 5)

            if let description = team.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 5)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }

    private var tabBarView: some View {
        HStack(spacing: 0) {
            ForEach(["Players", "Matches", "Stats"], id: \.self) { tab in
                Button(action: {
                    withAnimation {
                        activeTab = ["Players", "Matches", "Stats"].firstIndex(of: tab) ?? 0
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(activeTab == ["Players", "Matches", "Stats"].firstIndex(of: tab) ? .blue : .gray)

                        // 下划线指示器
                        Rectangle()
                            .fill(activeTab == ["Players", "Matches", "Stats"].firstIndex(of: tab) ? Color.blue : Color.clear)
                            .frame(height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .frame(height: 44)
    }

    private var playersTabView: some View {
        VStack {
            if teamPlayers.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text("No Players Yet")
                        .font(.headline)
                        .foregroundColor(.gray)

                    Button(action: {
                        showingAddPlayer = true
                    }) {
                        Label("Add Player", systemImage: "person.badge.plus")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 50)
            } else {
                List {
                    ForEach(teamPlayers) { player in
                        NavigationLink(destination: PlayerDetailView(player: player, firebaseService: firebaseService)) {
                            HStack(spacing: 12) {
                                // Player avatar
                                if let avatarURL = player.avatarURL, !avatarURL.isEmpty {
                                    AsyncImage(url: URL(string: avatarURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundColor(.gray.opacity(0.3))
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray.opacity(0.3))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player.name)
                                        .font(.headline)

                                    Text(player.position)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Stats summary
                                VStack(alignment: .trailing) {
                                    Text("Matches: \(player.stats.totalMatches)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                removePlayer(player)
                            } label: {
                                Label("Remove", systemImage: "person.fill.xmark")
                            }
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button(action: {
                        showingAddPlayer = true
                    }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .padding()
                            .background(Circle().fill(Color.blue))
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }
                    .padding()
                }
            }
        }
    }

    private var matchesTabView: some View {
        VStack {
            if teamMatches.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text("No Match Records")
                        .font(.headline)
                        .foregroundColor(.gray)

                    Text("Matches involving this team will appear here")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 50)
            } else {
                List {
                    ForEach(teamMatches) { match in
                        NavigationLink(destination: MatchDetailView(match: match, firebaseService: firebaseService)) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(match.teamA) vs \(match.teamB)")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(match.score.teamA) : \(match.score.teamB)")
                                        .font(.headline)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(statusColor(for: match).opacity(0.2))
                                        .cornerRadius(4)
                                }

                                HStack {
                                    Circle()
                                        .fill(statusColor(for: match))
                                        .frame(width: 8, height: 8)
                                    Text(statusText(for: match))
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text(formattedDate(match.createdAt))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var statsTabView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 整体统计
                VStack(alignment: .leading, spacing: 10) {
                    Text("Performance")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading)

                    HStack(spacing: 20) {
                        StatView(title: "Matches", value: team.stats.totalMatches)
                        StatView(title: "Wins", value: team.stats.wins, color: .green)
                        StatView(title: "Losses", value: team.stats.losses, color: .red)
                    }

                    if team.stats.totalMatches > 0 {
                        HStack {
                            // 胜率图表
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)

                                Circle()
                                    .trim(from: 0, to: CGFloat(team.stats.winRate))
                                    .stroke(
                                        team.stats.winRate >= 0.5 ? Color.green : Color.orange,
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))

                                VStack {
                                    Text("\(Int(team.stats.winRate * 100))%")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(team.stats.winRate >= 0.5 ? .green : .orange)

                                    Text("Win Rate")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: 130, height: 130)
                            .padding()

                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("Points Scored:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(team.stats.totalPoints)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                }

                                if team.stats.draws > 0 {
                                    HStack {
                                        Text("Draws:")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(team.stats.draws)")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }
                                }

                                Divider()

                                if team.stats.totalMatches > 0 {
                                    HStack {
                                        Text("Average Points:")
                                            .font(.subheadline)
                                        Spacer()
                                        Text(String(format: "%.1f", Double(team.stats.totalPoints) / Double(team.stats.totalMatches)))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                            .padding(.trailing)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)

                // 球员表现排名
                if !teamPlayers.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Top Players")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading)

                        ForEach(teamPlayers.sorted { $0.stats.scoreCount > $1.stats.scoreCount }.prefix(3), id: \.id) { player in
                            HStack {
                                if let avatarURL = player.avatarURL, !avatarURL.isEmpty {
                                    AsyncImage(url: URL(string: avatarURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundColor(.gray.opacity(0.3))
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray.opacity(0.3))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player.name)
                                        .font(.headline)

                                    Text(player.position)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(player.stats.scoreCount)")
                                        .font(.headline)
                                        .foregroundColor(.green)

                                    Text("Points")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func loadTransferable(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        isLoading = true

        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        self.logoImage = image
                        Task {
                            do {
                                if let id = team.id {
                                    try await firebaseService.updateTeamLogo(teamId: id, imageData: data)
                                }
                            } catch {
                                errorMessage = "Failed to update logo: \(error.localizedDescription)"
                            }
                        }
                    }
                case .failure(let error):
                    errorMessage = "Failed to load image: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadLogo(from urlString: String) {
        // 检查是否是本地URL或远程URL
        if urlString.hasPrefix("file://") {
            // 从本地存储加载
            if let image = LocalDataStore.shared.loadTeamLogo(from: urlString) {
                DispatchQueue.main.async {
                    self.logoImage = image
                }
            }
        } else {
            // 从远程URL加载
            guard let url = URL(string: urlString) else { return }

            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.logoImage = image
                    }
                }
            }.resume()
        }
    }

    private func loadTeamData() async {
        isLoading = true
        defer { isLoading = false }

        await loadTeamPlayers()
        await loadTeamMatches()
    }

    private func loadTeamPlayers() async {
        guard let teamId = team.id else { return }

        do {
            teamPlayers = try await firebaseService.getTeamPlayers(teamId: teamId)
        } catch {
            errorMessage = "Failed to load team players: \(error.localizedDescription)"
        }
    }

    private func loadTeamMatches() async {
        guard let teamId = team.id else { return }

        do {
            teamMatches = try await firebaseService.getTeamMatches(teamId: teamId)
        } catch {
            errorMessage = "Failed to load team matches: \(error.localizedDescription)"
        }
    }

    private func removePlayer(_ player: PlayerProfile) {
        guard let teamId = team.id, let playerId = player.id else { return }

        Task {
            do {
                try await firebaseService.removePlayerFromTeam(teamId: teamId, playerId: playerId)
                await loadTeamPlayers()
            } catch {
                errorMessage = "Failed to remove player: \(error.localizedDescription)"
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func statusColor(for match: Match) -> Color {
        switch match.status {
        case .created:
            return .yellow
        case .inProgress:
            return .green
        case .finished:
            return .blue
        }
    }

    private func statusText(for match: Match) -> String {
        switch match.status {
        case .created:
            return "Pending"
        case .inProgress:
            return "In Progress"
        case .finished:
            return "Completed"
        }
    }
}