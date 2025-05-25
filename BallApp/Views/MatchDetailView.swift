

import SwiftUI

struct MatchDetailView: View {
    @State var match: Match
    let firebaseService: FirebaseService

    @State private var showingAddPlayer = false
    @State private var showingAddEvent = false
    @State private var selectedTeamForPlayer: Bool = true // true for teamA, false for teamB
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSharePresented = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Scoreboard
                scoreboardSection

                // Status controls
                matchStatusSection

                // Player lists
                playersSection

                // Score chart
                scoreChartSection

                // Match action records
                eventsSection
            }
            .padding()
        }
        .navigationTitle("\(match.teamA) vs \(match.teamB)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        isSharePresented = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }

                    if match.status == .inProgress {
                        Button(action: {
                            showingAddEvent = true
                        }) {
                            Image(systemName: "plus.circle")
                        }
                        .disabled(match.playersA.isEmpty || match.playersB.isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(
                firebaseService: firebaseService,
                matchId: match.id ?? "",
                teamName: selectedTeamForPlayer ? match.teamA : match.teamB,
                isTeamA: selectedTeamForPlayer,
                onPlayerAdded: {
                    Task {
                        await refreshMatch()
                    }
                }
            )
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(
                firebaseService: firebaseService,
                match: match,
                onEventAdded: {
                    Task {
                        await refreshMatch()
                    }
                }
            )
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
        .sheet(isPresented: $isSharePresented) {
            ActivityView(activityItems: [createShareText()])
        }
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            // Refresh match data when view appears
            if let id = match.id {
                Task {
                    await refreshMatch()
                }
            }
        }
    }

    private var scoreboardSection: some View {
        VStack {
            Text("Score")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)

            HStack(alignment: .top, spacing: 20) {
                VStack {
                    Text(match.teamA)
                        .font(.headline)
                    Text("\(match.score.teamA)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text(match.teamB)
                        .font(.headline)
                    Text("\(match.score.teamB)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private var matchStatusSection: some View {
        VStack {
            Text("Match Status")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)

            HStack(spacing: 20) {
                switch match.status {
                case .created:
                    Button(action: startMatch) {
                        Label("Start Match", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(match.playersA.count < 2 || match.playersB.count < 2)

                case .inProgress:
                    Button(action: endMatch) {
                        Label("End Match", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                case .finished:
                    Text("Match Completed")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }

    private var playersSection: some View {
        VStack {
            Text("Players")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)

            HStack(alignment: .top, spacing: 20) {
                // Team A Players
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(match.teamA)
                            .font(.headline)
                        Spacer()
                        if match.status == .created {
                            Button(action: {
                                selectedTeamForPlayer = true
                                showingAddPlayer = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.bottom, 4)

                    if match.playersA.isEmpty {
                        Text("No players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(Array(match.playersA.enumerated()), id: \.offset) { index, player in
                            PlayerRow(player: player, number: index + 1)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                // Team B Players
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(match.teamB)
                            .font(.headline)
                        Spacer()
                        if match.status == .created {
                            Button(action: {
                                selectedTeamForPlayer = false
                                showingAddPlayer = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.bottom, 4)

                    if match.playersB.isEmpty {
                        Text("No players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(Array(match.playersB.enumerated()), id: \.offset) { index, player in
                            PlayerRow(player: player, number: index + 1)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private var scoreChartSection: some View {
        VStack {
            Text("Score Chart")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)

            if scoreEvents.count <= 1 {
                Text("No score data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            } else {
                ScoreChartView(scoreEvents: scoreEvents, teamA: match.teamA, teamB: match.teamB)
                    .frame(height: 200)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }

    // 处理比分事件数据
    private var scoreEvents: [ScoreEvent] {
        var events: [ScoreEvent] = []
        var scoreA = 0
        var scoreB = 0

        // 添加初始点，比赛开始时的比分为 0-0
        events.append(ScoreEvent(
            timestamp: match.createdAt,
            scoreA: 0,
            scoreB: 0
        ))

        // 按时间顺序遍历事件
        let sortedEvents = match.events
            .filter { $0.type == .scorePoint }
            .sorted { $0.timestamp < $1.timestamp }

        for event in sortedEvents {
            if event.teamId == match.teamA {
                scoreA += 1
            } else if event.teamId == match.teamB {
                scoreB += 1
            }

            events.append(ScoreEvent(
                timestamp: event.timestamp,
                scoreA: scoreA,
                scoreB: scoreB
            ))
        }

        return events
    }

    private var eventsSection: some View {
        VStack {
            Text("Match Records")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)

            if match.events.isEmpty {
                Text("No match records yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(match.events.sorted { $0.timestamp > $1.timestamp }) { event in
                        EventRow(event: event, teamA: match.teamA, teamB: match.teamB)
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private func startMatch() {
        guard match.playersA.count >= 2 && match.playersB.count >= 2 else {
            errorMessage = "Each team needs at least 2 players to start the match"
            return
        }

        updateMatchStatus(.inProgress)
    }

    private func endMatch() {
        updateMatchStatus(.finished)
    }

    private func updateMatchStatus(_ status: MatchStatus) {
        guard let id = match.id else {
            errorMessage = "Invalid match ID"
            return
        }

        isLoading = true

        Task {
            do {
                try await firebaseService.updateMatchStatus(matchId: id, status: status)
                await refreshMatch()
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to update match status: \(error.localizedDescription)"
                }
            }
        }
    }

    private func refreshMatch() async {
        guard let id = match.id else { return }

        DispatchQueue.main.async {
            self.isLoading = true
        }

        do {
            let updatedMatch = try await firebaseService.getMatch(id: id)
            DispatchQueue.main.async {
                print("Refreshing UI with player data: TeamA=\(updatedMatch.playersA.map { $0.name })")
                print("Refreshing UI with player data: TeamB=\(updatedMatch.playersB.map { $0.name })")
                self.match = updatedMatch
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to get match information: \(error.localizedDescription)"
            }
        }
    }

    private func createShareText() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let statusText: String
        switch match.status {
        case .created:
            statusText = "Not Started"
        case .inProgress:
            statusText = "In Progress"
        case .finished:
            statusText = "Completed"
        }

        var shareText = """
        Match Details: \(match.teamA) vs \(match.teamB)
        Date: \(dateFormatter.string(from: match.createdAt))
        Status: \(statusText)
        Score: \(match.score.teamA) - \(match.score.teamB)

        Teams:
        """

        // Add Team A players
        shareText += "\n\n\(match.teamA):"
        if match.playersA.isEmpty {
            shareText += "\nNo players"
        } else {
            for (index, player) in match.playersA.enumerated() {
                shareText += "\n\(index + 1). \(player.name) (\(player.position))"
            }
        }

        // Add Team B players
        shareText += "\n\n\(match.teamB):"
        if match.playersB.isEmpty {
            shareText += "\nNo players"
        } else {
            for (index, player) in match.playersB.enumerated() {
                shareText += "\n\(index + 1). \(player.name) (\(player.position))"
            }
        }

        // Add event records
        shareText += "\n\nMatch Records:"
        if match.events.isEmpty {
            shareText += "\nNo records yet"
        } else {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"

            for event in match.events.sorted(by: { $0.timestamp > $1.timestamp }) {
                let team = event.teamId == match.teamA ? match.teamA : match.teamB
                let actionType: String
                switch event.type {
                case .serve:
                    actionType = "Serve"
                case .forehand:
                    actionType = "Forehand"
                case .backhand:
                    actionType = "Backhand"
                case .scorePoint:
                    actionType = "Score"
                case .error:
                    actionType = "Error"
                }

                shareText += "\n\(timeFormatter.string(from: event.timestamp)) - \(event.playerName) (\(team)): \(actionType)"
            }
        }

        return shareText
    }
}

struct PlayerRow: View {
    let player: Player
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(number)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                Text(player.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack {
                Spacer()
                Text(player.position)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct EventRow: View {
    let event: MatchEvent
    let teamA: String
    let teamB: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(event.playerName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(actionText)
                    .font(.caption)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(teamText)
                    .font(.caption)
                    .foregroundColor(teamColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(teamColor.opacity(0.1))
                    .cornerRadius(4)

                Text(timeText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }

    private var actionText: String {
        switch event.type {
        case .serve:
            return "Serve"
        case .forehand:
            return "Forehand"
        case .backhand:
            return "Backhand"
        case .scorePoint:
            return "Score"
        case .error:
            return "Error"
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: event.timestamp)
    }

    private var teamText: String {
        return event.teamId == teamA ? teamA : teamB
    }

    private var teamColor: Color {
        return event.teamId == teamA ? .blue : .red
    }
}

// 添加ActivityView用于分享功能
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// 用于图表的比分事件数据结构
struct ScoreEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let scoreA: Int
    let scoreB: Int
}

// 比分折线图视图
struct ScoreChartView: View {
    let scoreEvents: [ScoreEvent]
    let teamA: String
    let teamB: String

    @State private var showingDetailIndex: Int? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // 背景网格线
                gridLines

                // 团队A的折线和数据点
                if scoreEvents.count > 1 {
                    teamAPath(in: geometry)
                }
                teamAPoints(in: geometry)

                // 团队B的折线和数据点
                if scoreEvents.count > 1 {
                    teamBPath(in: geometry)
                }
                teamBPoints(in: geometry)

                // 图例
                legendView

                // 详情提示
                detailTooltip(in: geometry)
            }
        }
    }

    // 网格线
    private var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<5) { i in
                Divider()
                    .frame(height: 1)
                if i < 4 {
                    Spacer()
                }
            }
        }
        .foregroundColor(Color.gray.opacity(0.3))
    }

    // 团队A的折线
    private func teamAPath(in geometry: GeometryProxy) -> some View {
        Path { path in
            let maxScore = maxScoreValue
            let width = geometry.size.width
            let height = geometry.size.height

            // 计算点的位置
            let points = scoreEvents.enumerated().map { (index, event) -> CGPoint in
                let x = width * CGFloat(index) / CGFloat(max(scoreEvents.count - 1, 1))
                let y = height - (height * CGFloat(event.scoreA) / CGFloat(max(maxScore, 1)))
                return CGPoint(x: x, y: y)
            }

            // 绘制路径
            if let firstPoint = points.first {
                path.move(to: firstPoint)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(Color.blue, lineWidth: 2)
    }

    // 团队A的数据点
    private func teamAPoints(in geometry: GeometryProxy) -> some View {
        ForEach(scoreEvents.indices, id: \.self) { index in
            pointView(for: index, team: .a, in: geometry)
        }
    }

    // 团队B的折线
    private func teamBPath(in geometry: GeometryProxy) -> some View {
        Path { path in
            let maxScore = maxScoreValue
            let width = geometry.size.width
            let height = geometry.size.height

            // 计算点的位置
            let points = scoreEvents.enumerated().map { (index, event) -> CGPoint in
                let x = width * CGFloat(index) / CGFloat(max(scoreEvents.count - 1, 1))
                let y = height - (height * CGFloat(event.scoreB) / CGFloat(max(maxScore, 1)))
                return CGPoint(x: x, y: y)
            }

            // 绘制路径
            if let firstPoint = points.first {
                path.move(to: firstPoint)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(Color.red, lineWidth: 2)
    }

    // 团队B的数据点
    private func teamBPoints(in geometry: GeometryProxy) -> some View {
        ForEach(scoreEvents.indices, id: \.self) { index in
            pointView(for: index, team: .b, in: geometry)
        }
    }

    // 图例
    private var legendView: some View {
        HStack(spacing: 20) {
            HStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text(teamA)
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text(teamB)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(6)
        .background(Color.white.opacity(0.8))
        .cornerRadius(4)
        .padding(8)
    }

    // 详情提示
    private func detailTooltip(in geometry: GeometryProxy) -> some View {
        Group {
            if let index = showingDetailIndex, scoreEvents.indices.contains(index) {
                let event = scoreEvents[index]
                let formatter = DateFormatter()
              

                VStack(alignment: .leading, spacing: 4) {
                    Text("Time: \(formatter.string(from: event.timestamp))")
                        .font(.caption)
                    Text("\(teamA): \(event.scoreA)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(teamB): \(event.scoreB)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(6)
                .background(Color.white)
                .cornerRadius(6)
                .shadow(radius: 2)
                .position(
                    x: geometry.size.width * CGFloat(index) / CGFloat(max(scoreEvents.count - 1, 1)),
                    y: 40
                )
                .onTapGesture {
                    showingDetailIndex = nil
                }
            }
        }
    }

    // 枚举表示团队
    private enum Team {
        case a, b
    }

    // 单个数据点视图
    private func pointView(for index: Int, team: Team, in geometry: GeometryProxy) -> some View {
        let event = scoreEvents[index]
        let maxScore = maxScoreValue
        let width = geometry.size.width
        let height = geometry.size.height

        let score = team == .a ? event.scoreA : event.scoreB
        let x = width * CGFloat(index) / CGFloat(max(scoreEvents.count - 1, 1))
        let y = height - (height * CGFloat(score) / CGFloat(max(maxScore, 1)))

        return Circle()
            .fill(team == .a ? Color.blue : Color.red)
            .frame(width: 8, height: 8)
            .position(x: x, y: y)
            .onTapGesture {
                showingDetailIndex = index
            }
    }

    // 计算最大分数，用于确定图表Y轴比例
    private var maxScoreValue: Int {
        let maxA = scoreEvents.map { $0.scoreA }.max() ?? 0
        let maxB = scoreEvents.map { $0.scoreB }.max() ?? 0
        return max(maxA, maxB, 1) // 确保至少为1，避免除以零
    }
}

#Preview {
    NavigationView {
        MatchDetailView(
            match: Match(
                id: "preview",
                teamA: "Team A",
                teamB: "Team B",
                playersA: [
                    Player(id: "1", name: "John Smith", position: "Attacker"),
                    Player(id: "2", name: "Mike Johnson", position: "Defender")
                ],
                playersB: [
                    Player(id: "3", name: "David Brown", position: "Attacker"),
                    Player(id: "4", name: "James Wilson", position: "Blocker")
                ],
                score: Score(teamA: 5, teamB: 3),
                events: [],
                status: .inProgress,
                createdAt: Date()
            ),
            firebaseService: FirebaseService()
        )
    }
}
