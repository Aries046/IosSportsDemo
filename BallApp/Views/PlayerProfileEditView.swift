import SwiftUI
import PhotosUI

struct PlayerProfileEditView: View {
    let firebaseService: FirebaseService
    var player: PlayerProfile?
    var avatarImage: UIImage?
    let onPlayerSaved: (PlayerProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var position: String = ""
    @State private var age: String = ""
    @State private var nationality: String = ""
    @State private var bio: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var newAvatarImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let positions = ["Attacker", "Defender", "All-Round", "Chopper", "Blocker"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Photo")) {
                    HStack {
                        Spacer()

                        ZStack(alignment: .bottomTrailing) {
                            // Avatar image
                            Group {
                                if let newAvatarImage = newAvatarImage {
                                    Image(uiImage: newAvatarImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else if let avatarImage = avatarImage {
                                    Image(uiImage: avatarImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else if let avatarURL = player?.avatarURL, !avatarURL.isEmpty {
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
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 2)

                            // Edit button for avatar
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                                    .background(Circle().fill(Color.white))
                            }
                            .onChange(of: selectedItem) { _ in
                                loadTransferable(from: selectedItem)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical)
                }

                Section(header: Text("Basic Information")) {
                    TextField("Name", text: $name)

                    Picker("Position", selection: $position) {
                        ForEach(positions, id: \.self) { pos in
                            Text(pos).tag(pos)
                        }
                    }

                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)

                    TextField("Nationality", text: $nationality)
                }

                Section(header: Text("Bio")) {
                    TextEditor(text: $bio)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(player == nil ? "New Player" : "Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlayer()
                    }
                    .disabled(name.isEmpty)
                }
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
                // Pre-fill form if editing an existing player
                if let player = player {
                    name = player.name
                    position = player.position
                    age = player.age != nil ? "\(player.age!)" : ""
                    nationality = player.nationality ?? ""
                    bio = player.bio ?? ""
                } else {
                    // Default values for new player
                    position = positions.first ?? "Attacker"
                }
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
                        self.newAvatarImage = image
                    }
                case .failure(let error):
                    errorMessage = "Failed to load image: \(error.localizedDescription)"
                }
            }
        }
    }

    private func savePlayer() {
        isLoading = true

        let ageValue = Int(age)

        let updatedPlayer = PlayerProfile(
            id: player?.id,
            name: name,
            position: position,
            age: ageValue,
            nationality: nationality.isEmpty ? nil : nationality,
            avatarURL: player?.avatarURL,
            bio: bio.isEmpty ? nil : bio,
            stats: player?.stats ?? PlayerStats(),
            createdAt: player?.createdAt ?? Date()
        )

        Task {
            do {
                let playerId = try await firebaseService.savePlayerProfile(updatedPlayer)

                // Upload avatar if a new one was selected
                if let newAvatarImage = newAvatarImage, let imageData = newAvatarImage.jpegData(compressionQuality: 0.8) {
                    _ = try await firebaseService.updatePlayerAvatar(playerId: playerId, imageData: imageData)
                }

                DispatchQueue.main.async {
                    isLoading = false
                    onPlayerSaved(updatedPlayer)
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to save player: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    PlayerProfileEditView(
        firebaseService: FirebaseService(),
        player: nil,
        onPlayerSaved: { _ in }
    )
}