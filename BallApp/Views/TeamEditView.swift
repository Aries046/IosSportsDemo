import SwiftUI
import PhotosUI

struct TeamEditView: View {
    let firebaseService: FirebaseService
    var team: Team?
    var logoImage: UIImage?
    let onTeamSaved: (Team) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var coach: String = ""
    @State private var foundedDate: Date = Date()
    @State private var description: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var newLogoImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDatePicker = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Logo")) {
                    HStack {
                        Spacer()

                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let newLogoImage = newLogoImage {
                                    Image(uiImage: newLogoImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else if let logoImage = logoImage {
                                    Image(uiImage: logoImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else if let logoURL = team?.logo, !logoURL.isEmpty {
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
                                        .padding(15)
                                        .foregroundColor(.gray.opacity(0.3))
                                }
                            }
                            .frame(width: 100, height: 100)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                            .shadow(radius: 2)

                            // 编辑按钮
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
                    TextField("Team Name", text: $name)

                    TextField("Coach", text: $coach)

                    HStack {
                        Text("Founded")
                        Spacer()
                        Button(action: {
                            showDatePicker.toggle()
                        }) {
                            Text(formattedDate(foundedDate))
                                .foregroundColor(.blue)
                        }
                    }

                    if showDatePicker {
                        DatePicker("", selection: $foundedDate, displayedComponents: .date)
                            .datePickerStyle(.wheel)
                    }
                }

                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(team == nil ? "New Team" : "Edit Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTeam()
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
                if let team = team {
                    name = team.name
                    coach = team.coach ?? ""
                    description = team.description ?? ""
                    if let date = team.foundedDate {
                        foundedDate = date
                    }
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
                        self.newLogoImage = image
                    }
                case .failure(let error):
                    errorMessage = "Failed to load image: \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveTeam() {
        isLoading = true

        let updatedTeam = Team(
            id: team?.id,
            name: name,
            logo: team?.logo,
            description: description.isEmpty ? nil : description,
            foundedDate: foundedDate,
            coach: coach.isEmpty ? nil : coach,
            playerIds: team?.playerIds ?? [],
            matchIds: team?.matchIds ?? [],
            stats: team?.stats ?? TeamStats(),
            createdAt: team?.createdAt ?? Date()
        )

        Task {
            do {
                let teamId = try await firebaseService.saveTeam(updatedTeam)

                // 上传新logo如果有选择的话
                if let newLogoImage = newLogoImage, let imageData = newLogoImage.jpegData(compressionQuality: 0.8) {
                    _ = try await firebaseService.updateTeamLogo(teamId: teamId, imageData: imageData)
                }

                DispatchQueue.main.async {
                    isLoading = false
                    onTeamSaved(updatedTeam)
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to save team: \(error.localizedDescription)"
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    TeamEditView(
        firebaseService: FirebaseService(),
        team: nil,
        onTeamSaved: { _ in }
    )
}
