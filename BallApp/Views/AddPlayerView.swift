//
//  AddPlayerView.swift
//  BallApp
//
//  Created by Cursor AI on 2025/5/24.
//

import SwiftUI

struct AddPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    let firebaseService: FirebaseService
    let matchId: String
    let teamName: String
    let isTeamA: Bool
    let onPlayerAdded: () -> Void

    @State private var playerName = ""
    @State private var playerPosition = "主攻"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let positions = ["主攻", "副攻", "二传", "自由人", "接应"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("添加球员到 \(teamName)")) {
                    TextField("球员姓名", text: $playerName)
                        .autocapitalization(.words)

                    Picker("位置", selection: $playerPosition) {
                        ForEach(positions, id: \.self) { position in
                            Text(position).tag(position)
                        }
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: addPlayer) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("添加球员")
                        }
                    }
                    .disabled(playerName.isEmpty || isLoading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("添加球员")
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

    private func addPlayer() {
        guard !playerName.isEmpty else {
            errorMessage = "请输入球员姓名"
            return
        }

        isLoading = true
        errorMessage = nil

        let player = Player(name: playerName, position: playerPosition)

        Task {
            do {
                try await firebaseService.addPlayer(to: matchId, player: player, isTeamA: isTeamA)
                DispatchQueue.main.async {
                    isLoading = false
                    onPlayerAdded()
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "添加球员失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    AddPlayerView(
        firebaseService: FirebaseService(),
        matchId: "preview",
        teamName: "铁军队",
        isTeamA: true,
        onPlayerAdded: {}
    )
}