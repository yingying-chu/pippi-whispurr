//
//  PetViews.swift
//  PippiWhispurr
//
//  Create, browse, and edit the pets whose stories live in PiPi.
//

import SwiftUI
import Photos
import PhotosUI
import UIKit

struct PetListView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @State private var showingNewPet = false
    @State private var petPendingDeletion: PetProfile?

    var body: some View {
        Group {
            if storyStore.pets.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(storyStore.pets) { pet in
                        NavigationLink(destination: PetProfileView(petID: pet.id)) {
                            PetRow(pet: pet)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                petPendingDeletion = pet
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("My Pets")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewPet = true
                } label: {
                    Label("Add Pet", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewPet) {
            NavigationView {
                PetEditorView()
            }
        }
        .alert(
            "Delete \(petPendingDeletion?.name ?? "this pet")?",
            isPresented: Binding(
                get: { petPendingDeletion != nil },
                set: { if !$0 { petPendingDeletion = nil } }
            ),
            presenting: petPendingDeletion
        ) { pet in
            Button("Delete", role: .destructive) {
                storyStore.deletePet(id: pet.id)
                petPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                petPendingDeletion = nil
            }
        } message: { _ in
            Text("Its memories and milestones will also be removed. This cannot be undone.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue)

            Text("Every story starts with a pet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Create a profile now. You can add photos and memories to it next.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Create My First Pet") {
                showingNewPet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct PetRow: View {
    let pet: PetProfile

    var body: some View {
        HStack(spacing: 14) {
            PetProfileImageView(
                assetIdentifier: pet.profilePhotoIdentifier,
                size: 52,
                fallback: speciesEmoji
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.headline)

                Text(detailText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var speciesEmoji: String {
        switch pet.species.lowercased() {
        case "dog": return "🐕"
        case "cat": return "🐈"
        default: return "🐾"
        }
    }

    private var detailText: String {
        if let breed = pet.breed, !breed.isEmpty {
            return "\(pet.species) · \(breed)"
        }
        return pet.species
    }
}

struct PetProfileView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @EnvironmentObject private var photoManager: PhotoManager
    let petID: UUID
    @State private var showingEditor = false

    private var pet: PetProfile? {
        storyStore.pets.first { $0.id == petID }
    }

    private var assignedPhotos: [PetPhoto] {
        let assignedIDs = Set(
            storyStore.photos
                .filter { $0.assignedPetIDs.contains(petID) }
                .map(\.assetIdentifier)
        )
        return photoManager.petPhotos.filter { assignedIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if let pet {
                ScrollView {
                    VStack(spacing: 24) {
                        PetProfileImageView(
                            assetIdentifier: pet.profilePhotoIdentifier,
                            size: 132,
                            fallback: speciesEmoji(for: pet)
                        )

                        VStack(spacing: 6) {
                            Text(pet.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text(profileSubtitle(for: pet))
                                .foregroundColor(.secondary)
                        }

                        if !pet.introduction.isEmpty {
                            Text(pet.introduction)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(14)
                        }

                        VStack(spacing: 0) {
                            profileTextRow(
                                title: "Gender",
                                systemImage: "figure.stand",
                                value: pet.gender?.displayName ?? "Not set"
                            )
                            Divider()
                            profileDateRow(
                                title: "Birthday",
                                systemImage: "birthday.cake",
                                date: pet.birthday
                            )
                            Divider()
                            profileDateRow(
                                title: "Adoption Day",
                                systemImage: "house.fill",
                                date: pet.adoptionDate
                            )
                            if pet.foodName != nil || pet.foodBrand != nil {
                                Divider()
                                profileTextRow(
                                    title: "Food",
                                    systemImage: "fork.knife",
                                    value: [pet.foodBrand, pet.foodName]
                                        .compactMap { $0 }
                                        .joined(separator: " · ")
                                )
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)

                        if assignedPhotos.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                Text("No photos assigned yet")
                                    .font(.headline)
                                Text("Open a photo in Library and choose Assign to a pet.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 28)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Photos")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("\(assignedPhotos.count)")
                                        .foregroundColor(.secondary)
                                }

                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible()), count: 3),
                                    spacing: 8
                                ) {
                                    ForEach(assignedPhotos) { photo in
                                        NavigationLink(destination: PhotoDetailView(photo: photo)) {
                                            PhotoThumbnailView(photo: photo)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle(pet.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") {
                            showingEditor = true
                        }
                    }
                }
                .sheet(isPresented: $showingEditor) {
                    NavigationView {
                        PetEditorView(pet: pet)
                    }
                }
            } else {
                Text("This pet profile is no longer available.")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func profileSubtitle(for pet: PetProfile) -> String {
        if let breed = pet.breed, !breed.isEmpty {
            return "\(pet.species) · \(breed)"
        }
        return pet.species
    }

    private func speciesEmoji(for pet: PetProfile) -> String {
        switch pet.species.lowercased() {
        case "dog": return "🐕"
        case "cat": return "🐈"
        default: return "🐾"
        }
    }

    private func profileTextRow(
        title: String,
        systemImage: String,
        value: String
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding()
    }

    private func profileDateRow(
        title: String,
        systemImage: String,
        date: Date?
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(date?.formatted(date: .abbreviated, time: .omitted) ?? "Not set")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct PetEditorView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @Environment(\.dismiss) private var dismiss

    private let existingPet: PetProfile?

    @State private var name: String
    @State private var species: String
    @State private var breed: String
    @State private var gender: PetProfile.Gender
    @State private var foodName: String
    @State private var foodBrand: String
    @State private var profilePhotoIdentifier: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var introduction: String
    @State private var lifeStatus: PetProfile.LifeStatus
    @State private var hasBirthday: Bool
    @State private var birthday: Date
    @State private var hasAdoptionDate: Bool
    @State private var adoptionDate: Date

    private let speciesOptions = ["Dog", "Cat", "Other"]

    init(pet: PetProfile? = nil) {
        existingPet = pet
        _name = State(initialValue: pet?.name ?? "")
        _species = State(initialValue: pet?.species ?? "Dog")
        _breed = State(initialValue: pet?.breed ?? "")
        _gender = State(initialValue: pet?.gender ?? .neutral)
        _foodName = State(initialValue: pet?.foodName ?? "")
        _foodBrand = State(initialValue: pet?.foodBrand ?? "")
        _profilePhotoIdentifier = State(initialValue: pet?.profilePhotoIdentifier)
        _selectedPhotoItem = State(initialValue: nil)
        _introduction = State(initialValue: pet?.introduction ?? "")
        _lifeStatus = State(initialValue: pet?.lifeStatus ?? .current)
        _hasBirthday = State(initialValue: pet?.birthday != nil)
        _birthday = State(initialValue: pet?.birthday ?? Date())
        _hasAdoptionDate = State(initialValue: pet?.adoptionDate != nil)
        _adoptionDate = State(initialValue: pet?.adoptionDate ?? Date())
    }

    var body: some View {
        Form {
            Section("Reference photo") {
                HStack(spacing: 16) {
                    PetProfileImageView(
                        assetIdentifier: profilePhotoIdentifier,
                        size: 72,
                        fallback: species == "Cat" ? "🐈" : (species == "Dog" ? "🐕" : "🐾")
                    )

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            profilePhotoIdentifier == nil ? "Choose a Photo" : "Change Photo",
                            systemImage: "photo"
                        )
                    }
                }

                Text("This photo is your pet's profile image now and can become a reference for individual matching later.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("About your pet") {
                TextField("Name", text: $name)

                Picker("Species", selection: $species) {
                    ForEach(speciesOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }

                if species == "Other" {
                    TextField("Breed (optional)", text: $breed)
                } else {
                    Picker("Breed", selection: $breed) {
                        Text("Not set").tag("")
                        ForEach(breedOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Picker("Gender", selection: $gender) {
                    ForEach(PetProfile.Gender.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }

                Picker("Story status", selection: $lifeStatus) {
                    Text("Current").tag(PetProfile.LifeStatus.current)
                    Text("Remembered").tag(PetProfile.LifeStatus.remembered)
                    Text("Memorial").tag(PetProfile.LifeStatus.memorial)
                }
            }

            Section("Food") {
                TextField("What are they eating?", text: $foodName)
                TextField("Brand", text: $foodBrand)
            }

            Section("Life dates") {
                Toggle("Add birthday", isOn: $hasBirthday)
                if hasBirthday {
                    DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                }

                Toggle("Add adoption day", isOn: $hasAdoptionDate)
                if hasAdoptionDate {
                    DatePicker("Adoption Day", selection: $adoptionDate, displayedComponents: .date)
                }
            }

            Section {
                TextEditor(text: $introduction)
                    .frame(minHeight: 100)
            } header: {
                Text("A little introduction")
            } footer: {
                Text("A few words about their personality is enough. You can always return later.")
            }
        }
        .navigationTitle(existingPet == nil ? "New Pet" : "Edit Pet")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { newItem in
            if let identifier = newItem?.itemIdentifier {
                profilePhotoIdentifier = identifier
            }
        }
        .onChange(of: species) { _ in
            if !breed.isEmpty && !breedOptions.contains(breed) {
                breed = ""
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(trimmedName.isEmpty)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let now = Date()
        let pet = PetProfile(
            id: existingPet?.id ?? UUID(),
            name: trimmedName,
            species: species,
            breed: breed.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            gender: gender,
            foodName: foodName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            foodBrand: foodBrand.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            birthday: hasBirthday ? birthday : nil,
            adoptionDate: hasAdoptionDate ? adoptionDate : nil,
            profilePhotoIdentifier: profilePhotoIdentifier,
            introduction: introduction.trimmingCharacters(in: .whitespacesAndNewlines),
            lifeStatus: lifeStatus,
            createdAt: existingPet?.createdAt ?? now,
            updatedAt: now
        )
        storyStore.upsertPet(pet)
        dismiss()
    }

    private var breedOptions: [String] {
        let standard: [String]
        switch species {
        case "Cat":
            standard = [
                "Domestic Shorthair", "Domestic Longhair", "Siamese",
                "British Shorthair", "Maine Coon", "Ragdoll", "Bengal",
                "Persian", "Sphynx", "Mixed", "Other"
            ]
        case "Dog":
            standard = [
                "Labrador Retriever", "Golden Retriever", "German Shepherd",
                "French Bulldog", "Poodle", "Beagle", "Shiba Inu",
                "Corgi", "Chihuahua", "Mixed", "Other"
            ]
        default:
            standard = []
        }

        if !breed.isEmpty && !standard.contains(breed) {
            return [breed] + standard
        }
        return standard
    }
}

private struct PetProfileImageView: View {
    let assetIdentifier: String?
    let size: CGFloat
    let fallback: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.12))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(fallback)
                    .font(size > 80 ? .system(size: 48) : .title2)
            }
        }
        .frame(width: size, height: size)
        .task(id: assetIdentifier) {
            await loadImage()
        }
    }

    private func loadImage() async {
        image = nil
        guard let assetIdentifier else { return }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = result.firstObject else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        image = await withCheckedContinuation { continuation in
            var hasResumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: size * 3, height: size * 3),
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: result)
            }
        }
    }
}

private extension PetProfile.Gender {
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .neutral: return "Neutral"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
