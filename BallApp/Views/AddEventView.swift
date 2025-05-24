//
//  AddEventView.swift
//  BallApp
//
//  Created by Cursor AI on 2025/5/24.
//

import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss

    let firebaseService: FirebaseService
    let match: Match
    let onEventAdded: () -> Void

    @State private var selectedPlayer: Player?
    @State private var selectedTeam: String = ""
    @State private var selectedEventType: EventType = .serve
    @State private var description: String = ""
    @State private var isTeamA: Bool = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var validationError: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("选择队伍")) {
                    Picker("队伍", selection: $isTeamA) {
                        Text(match.teamA).tag(true)
                        Text(match.teamB).tag(false)
                    }
                    .onChange(of: isTeamA) { newValue in
                        selectedTeam = newValue ? match.teamA : match.teamB
                        selectedPlayer = nil
                    }
                    .onAppear {
                        selectedTeam = isTeamA ? match.teamA : match.teamB
                    }
                }

                Section(header: Text("选择球员")) {
                    if availablePlayers.isEmpty {
                        Text("没有可用球员")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("球员", selection: $selectedPlayer) {
                            Text("请选择球员").tag(nil as Player?)
                            ForEach(availablePlayers) { player in
                                Text(player.name).tag(player as Player?)
                            }
                        }
                    }
                }

                Section(header: Text("动作类型")) {
                    Picker("动作", selection: $selectedEventType) {
                        Text("发球").tag(EventType.serve)
                        Text("正手击球").tag(EventType.forehand)
                        Text("反手击球").tag(EventType.backhand)
                        Text("得分").tag(EventType.scorePoint)
                        Text("失误").tag(EventType.error)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("备注")) {
                    TextField("可选", text: $description)
                        .autocapitalization(.sentences)
                }

                if let validationError = validationError {
                    Section {
                        Text(validationError)
                            .foregroundColor(.red)
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: addEvent) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("记录动作")
                        }
                    }
                    .disabled(selectedPlayer == nil || isLoading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("记录比赛动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var availablePlayers: [Player] {
        isTeamA ? match.playersA : match.playersB
    }

    private func addEvent() {
        guard let player = selectedPlayer else {
            validationError = "请选择一名球员"
            return
        }

        // 验证规则
        if selectedEventType == .forehand || selectedEventType == .backhand {
            if !validateHitAction() {
                validationError = "必须先有发球动作才能记录击球"
                return
            }
        }

        if selectedEventType == .scorePoint {
            if !validateScoreAction() {
                validationError = "必须在击球动作后才能记录得分"
                return
            }
        }

        validationError = nil
        isLoading = true
        errorMessage = nil

        let event = MatchEvent(
            type: selectedEventType,
            playerId: player.id ?? UUID().uuidString,
            playerName: player.name,
            teamId: isTeamA ? match.teamA : match.teamB,
            timestamp: Date(),
            description: description
        )

        Task {
            do {
                if let id = match.id {
                    try await firebaseService.addEvent(to: id, event: event)
                    DispatchQueue.main.async {
                        isLoading = false
                        onEventAdded()
                        dismiss()
                    }
                } else {
                    throw NSError(domain: "EventError", code: 404, userInfo: [NSLocalizedDescriptionKey: "比赛ID无效"])
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "添加事件失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func validateHitAction() -> Bool {
        // 规则1: 必须先有发球动作才能记录击球
        if match.events.isEmpty {
            return false
        }

        // 检查是否有发球动作
        return match.events.contains(where: { $0.type == .serve })
    }

    private func validateScoreAction() -> Bool {
        // 规则2: 必须在击球动作后才能记录得分
        if match.events.isEmpty {
            return false
        }

        // 找到最后一个动作
        if let lastEvent = match.events.last {
            // 检查最后一个动作是否是击球
            return lastEvent.type == .forehand || lastEvent.type == .backhand
        }

        return false
    }
}

#Preview {
    AddEventView(
        firebaseService: FirebaseService(),
        match: Match(
            id: "preview",
            teamA: "铁军队",
            teamB: "蓝鲸队",
            playersA: [
                Player(id: "1", name: "王刚", position: "主攻"),
                Player(id: "2", name: "李明", position: "副攻")
            ],
            playersB: [
                Player(id: "3", name: "张伟", position: "主攻"),
                Player(id: "4", name: "赵强", position: "副攻")
            ],
            score: Score(teamA: 0, teamB: 0),
            events: [],
            status: .inProgress,
            createdAt: Date()
        ),
        onEventAdded: {}
    )
}