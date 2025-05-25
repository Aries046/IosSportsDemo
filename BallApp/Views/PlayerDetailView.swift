import SwiftUI
import PhotosUI

struct PlayerDetailView: View {
    let player: PlayerProfile
    let firebaseService: FirebaseService

    @State private var isLoading = false
    @State private var isEditing = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile header with avatar
                VStack(spacing: 15) {
                    ZStack(alignment: .bottomTrailing) {
                        // Avatar image
                        Group {
                            if let avatarImage = avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if let avatarURL = player.avatarURL, !avatarURL.isEmpty {
                                AsyncImage(url: URL(string: avatarURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ProgressView()
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(radius: 3)

                        // Edit button for avatar
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

                    Text(player.name)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(player.position)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if let nationality = player.nationality, !nationality.isEmpty {
                        Text("From: \(nationality)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let age = player.age {
                        Text("Age: \(age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text("Joined \(formattedDate(player.createdAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(15)

                // Bio section
                if let bio = player.bio, !bio.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("About")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(bio)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                }

                // Stats section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Statistics")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack {
                        StatView(title: "Matches", value: player.stats.totalMatches)
                        Divider()
                        StatView(title: "Wins", value: player.stats.wins)
                        Divider()
                        StatView(title: "Losses", value: player.stats.losses)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    HStack {
                        StatView(title: "Serves", value: player.stats.serveCount)
                        Divider()
                        StatView(title: "Forehand", value: player.stats.forehandCount)
                        Divider()
                        StatView(title: "Backhand", value: player.stats.backhandCount)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    HStack {
                        StatView(title: "Points", value: player.stats.scoreCount, color: .green)
                        Divider()
                        StatView(title: "Errors", value: player.stats.errorCount, color: .red)
                        Divider()
                        if player.stats.totalMatches > 0 {
                            StatView(title: "Win Rate", value: "\(Int(player.stats.winRate * 100))%",
                                     color: player.stats.winRate >= 0.5 ? .green : .orange)
                        } else {
                            StatView(title: "Win Rate", value: "0%", color: .gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
            }
            .padding()
        }
        .navigationTitle("Player Profile")
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
            PlayerProfileEditView(
                firebaseService: firebaseService,
                player: player,
                avatarImage: avatarImage,
                onPlayerSaved: { _ in
                    // This would typically refresh the player data
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
            if let avatarURL = player.avatarURL, !avatarURL.isEmpty {
                loadAvatar(from: avatarURL)
            }
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
                        self.avatarImage = image
                        Task {
                            do {
                                if let id = player.id {
                                    try await firebaseService.updatePlayerAvatar(playerId: id, imageData: data)
                                }
                            } catch {
                                errorMessage = "Failed to update avatar: \(error.localizedDescription)"
                            }
                        }
                    }
                case .failure(let error):
                    errorMessage = "Failed to load image: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadAvatar(from urlString: String) {

        if urlString.hasPrefix("file://") {

            if let image = LocalDataStore.shared.loadPlayerAvatar(from: urlString) {
                DispatchQueue.main.async {
                    self.avatarImage = image
                }
            }
        } else {

            guard let url = URL(string: urlString) else { return }

            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.avatarImage = image
                    }
                }
            }.resume()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct StatView: View {
    let title: String
    let value: Any
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView {
        PlayerDetailView(
            player: PlayerProfile(
                id: "preview",
                name: "John Smith",
                position: "Attacker",
                age: 24,
                nationality: "USA",
                bio: "Professional table tennis player with 5 years of experience. Specializes in powerful forehand attacks and quick footwork.",
                stats: PlayerStats(
                    totalMatches: 45,
                    wins: 30,
                    losses: 15,
                    serveCount: 320,
                    forehandCount: 560,
                    backhandCount: 280,
                    scoreCount: 220,
                    errorCount: 85
                )
            ),
            firebaseService: FirebaseService()
        )
    }
}
