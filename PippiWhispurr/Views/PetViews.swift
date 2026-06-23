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
    @State private var selectedPetID: UUID?

    private var activePetID: UUID? {
        if let selectedPetID,
           storyStore.pets.contains(where: { $0.id == selectedPetID }) {
            return selectedPetID
        }
        return storyStore.pets.first?.id
    }

    var body: some View {
        Group {
            if storyStore.pets.isEmpty {
                emptyState
            } else if let activePetID {
                VStack(spacing: 0) {
                    if storyStore.pets.count > 1 {
                        petSwitcher
                        Divider()
                    }

                    PetProfileView(petID: activePetID)
                }
            }
        }
        .toolbar {
            if storyStore.pets.count <= 1 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    addPetButton
                }
            }
        }
        .onAppear {
            selectedPetID = activePetID
        }
        .onChange(of: storyStore.pets.map(\.id)) { _ in
            selectedPetID = activePetID
        }
        .sheet(isPresented: $showingNewPet) {
            NavigationView {
                PetEditorView()
            }
        }
    }

    private var addPetButton: some View {
        Button {
            showingNewPet = true
        } label: {
            Label("Add Pet", systemImage: "plus")
        }
    }

    private var petSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(storyStore.pets) { pet in
                    Button {
                        selectedPetID = pet.id
                    } label: {
                        VStack(spacing: 5) {
                            PetProfileImageView(
                                assetIdentifier: pet.profilePhotoIdentifier,
                                size: 48,
                                fallback: speciesEmoji(for: pet)
                            )
                            .overlay {
                                if activePetID == pet.id {
                                    Circle().stroke(Color.blue, lineWidth: 3)
                                }
                            }

                            Text(pet.name)
                                .font(.caption.weight(activePetID == pet.id ? .bold : .regular))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showingNewPet = true
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 48, height: 48)
                            .background(Color(.secondarySystemFill))
                            .clipShape(Circle())
                        Text("Add")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func speciesEmoji(for pet: PetProfile) -> String {
        switch pet.species.lowercased() {
        case "dog": return "🐕"
        case "cat": return "🐈"
        default: return "🐾"
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

struct PetProfileView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @EnvironmentObject private var photoManager: PhotoManager
    let petID: UUID
    @State private var showingEditor = false
    @State private var showingJournalEditor = false

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

    private var recentMemories: [MemoryEntry] {
        storyStore.memories
            .filter { $0.petIDs.contains(petID) }
            .sorted { $0.memoryDate > $1.memoryDate }
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

                        Button {
                            showingJournalEditor = true
                        } label: {
                            Label("Record a Story", systemImage: "square.and.pencil")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Stories")
                                    .font(.title2.bold())
                                Spacer()
                                Text("\(recentMemories.count)")
                                    .foregroundColor(.secondary)
                            }

                            if recentMemories.isEmpty {
                                Text("Birthdays, adventures, and tiny everyday moments will live here.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(14)
                            } else {
                                ForEach(recentMemories.prefix(3)) { memory in
                                    NavigationLink(destination: JournalDetailView(memoryID: memory.id)) {
                                        HStack(spacing: 12) {
                                            Image(systemName: memory.kind?.systemImage ?? "book.closed")
                                                .foregroundColor(.orange)
                                                .frame(width: 28)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(memory.title.isEmpty ? memory.kind?.displayName ?? "A memory" : memory.title)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                Text(memory.memoryDate.formatted(date: .abbreviated, time: .omitted))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption.bold())
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .cornerRadius(14)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(spacing: 0) {
                            profileTextRow(
                                title: "Sex",
                                systemImage: "pawprint.fill",
                                value: sexDescription(for: pet)
                            )
                            Divider()
                            profileDateRow(
                                title: "Birthday",
                                systemImage: "birthday.cake",
                                date: pet.birthday,
                                showsAge: true
                            )
                            if pet.adoptionDate != nil {
                                Divider()
                                profileDateRow(
                                    title: "Adoption Day",
                                    systemImage: "house.fill",
                                    date: pet.adoptionDate
                                )
                            }
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
                                        NavigationLink(destination: PhotoDetailView(photo: photo, photos: assignedPhotos)) {
                                            PhotoThumbnailView(photo: photo)
                                        }
                                    }
                                }
                            }
                        }

                        NavigationLink(destination: PetHealthView(petID: pet.id)) {
                            HStack(spacing: 10) {
                                Image(systemName: "heart.text.clipboard")
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Care Notes")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text(healthSummary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
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
                .sheet(isPresented: $showingJournalEditor) {
                    NavigationView {
                        NewJournalEntryView(petIDs: [pet.id])
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

    private var healthSummary: String {
        guard let latest = storyStore.healthCheckIns
            .filter({ $0.petID == petID })
            .max(by: { $0.date < $1.date }) else {
            return "Start a quick check-in"
        }
        return "Last check-in \(latest.date.formatted(date: .abbreviated, time: .omitted))"
    }

    private func speciesEmoji(for pet: PetProfile) -> String {
        switch pet.species.lowercased() {
        case "dog": return "🐕"
        case "cat": return "🐈"
        default: return "🐾"
        }
    }

    private func sexDescription(for pet: PetProfile) -> String {
        switch pet.gender {
        case .male:
            return pet.isSpayedOrNeutered == true ? "Male (neutered)" : "Male"
        case .female:
            return pet.isSpayedOrNeutered == true ? "Female (spayed)" : "Female"
        case .neutral, .none:
            return pet.isSpayedOrNeutered == true ? "Spayed / neutered" : "Not set"
        }
    }

    private func profileTextRow(
        title: String,
        systemImage: String,
        value: String
    ) -> some View {
        HStack {
            Image(systemName: systemImage)
                .frame(width: 24)
            Text(title)
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
        date: Date?,
        showsAge: Bool = false
    ) -> some View {
        HStack {
            Image(systemName: systemImage)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(dateDescription(date, showsAge: showsAge))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding()
    }

    private func dateDescription(_ date: Date?, showsAge: Bool) -> String {
        guard let date else { return "Not set" }
        let formatted = date.formatted(date: .abbreviated, time: .omitted)
        guard showsAge, date <= Date() else { return formatted }

        let components = Calendar.current.dateComponents([.year, .month], from: date, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0
        let age: String
        if years == 0 {
            age = months == 1 ? "1 month old" : "\(months) months old"
        } else {
            age = years == 1 ? "1 year old" : "\(years) years old"
        }
        return "\(formatted) (\(age))"
    }
}

struct PetEditorView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @EnvironmentObject private var photoManager: PhotoManager
    @Environment(\.dismiss) private var dismiss

    private let existingPet: PetProfile?

    @State private var name: String
    @State private var species: String
    @State private var breed: String
    @State private var gender: PetProfile.Gender
    @State private var isSpayedOrNeutered: Bool?
    @State private var foodName: String
    @State private var foodBrand: String
    @State private var profilePhotoIdentifier: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingScannedPhotoPicker = false
    @State private var introduction: String
    @State private var lifeStatus: PetProfile.LifeStatus
    @State private var hasBirthday: Bool
    @State private var birthday: Date
    @State private var hasAdoptionDate: Bool
    @State private var adoptionDate: Date
    @State private var showingDeleteConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case breed
        case foodName
        case foodBrand
        case introduction
    }

    private let speciesOptions = ["Dog", "Cat", "Other"]

    init(pet: PetProfile? = nil) {
        existingPet = pet
        _name = State(initialValue: pet?.name ?? "")
        _species = State(initialValue: pet?.species ?? "Dog")
        _breed = State(initialValue: pet?.breed ?? "")
        _gender = State(initialValue: pet?.gender ?? .neutral)
        _isSpayedOrNeutered = State(initialValue: pet?.isSpayedOrNeutered)
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        PetProfileImageView(
                            assetIdentifier: profilePhotoIdentifier,
                            size: 72,
                            fallback: species == "Cat" ? "🐈" : (species == "Dog" ? "🐕" : "🐾")
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                focusedField = nil
                                showingScannedPhotoPicker = true
                            } label: {
                                Label(
                                    profilePhotoIdentifier == nil ? "Choose Scanned Photo" : "Change Scanned Photo",
                                    systemImage: "photo.stack"
                                )
                            }
                            .buttonStyle(.borderedProminent)

                            Text("Pick from photos PiPi has already scanned.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose from Photo Library Instead", systemImage: "photo.on.rectangle")
                            .font(.subheadline)
                    }
                }

                Text("This photo is your pet's profile image now and can become a reference for individual matching later.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("About your pet") {
                TextField("Name", text: $name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }

                Picker("Species", selection: $species) {
                    ForEach(speciesOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }

                if species == "Other" {
                    TextField("Breed (optional)", text: $breed)
                        .focused($focusedField, equals: .breed)
                } else {
                    Picker("Breed", selection: $breed) {
                        Text("Not set").tag("")
                        ForEach(breedOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Picker("Sex", selection: $gender) {
                    ForEach(PetProfile.Gender.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }

                Picker("Spayed / neutered", selection: $isSpayedOrNeutered) {
                    Text("Not set").tag(Bool?.none)
                    Text("No").tag(Bool?.some(false))
                    Text(alteredStatusLabel).tag(Bool?.some(true))
                }

                Picker("Story status", selection: $lifeStatus) {
                    Text("Current").tag(PetProfile.LifeStatus.current)
                    Text("Remembered").tag(PetProfile.LifeStatus.remembered)
                    Text("Memorial").tag(PetProfile.LifeStatus.memorial)
                }
            }

            Section("Food") {
                TextField("What are they eating?", text: $foodName)
                    .focused($focusedField, equals: .foodName)
                TextField("Brand", text: $foodBrand)
                    .focused($focusedField, equals: .foodBrand)
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
                    .focused($focusedField, equals: .introduction)
            } header: {
                Text("A little introduction")
            } footer: {
                Text("A few words about their personality is enough. You can always return later.")
            }

            if existingPet != nil {
                Section {
                    Button("Delete Pet", role: .destructive) {
                        focusedField = nil
                        showingDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(existingPet == nil ? "New Pet" : "Edit Pet")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showingScannedPhotoPicker) {
            NavigationView {
                ScannedProfilePhotoPicker(
                    selectedIdentifier: profilePhotoIdentifier
                ) { identifier in
                    profilePhotoIdentifier = identifier
                    selectedPhotoItem = nil
                    showingScannedPhotoPicker = false
                }
            }
        }
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
        .alert("Delete this pet?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                guard let existingPet else { return }
                storyStore.deletePet(id: existingPet.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its stories, milestones, and care notes will also be removed. This cannot be undone.")
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

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
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
            isSpayedOrNeutered: isSpayedOrNeutered,
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

    private var alteredStatusLabel: String {
        switch gender {
        case .male: return "Neutered"
        case .female: return "Spayed"
        case .neutral: return "Yes"
        }
    }
}

private struct ScannedProfilePhotoPicker: View {
    @EnvironmentObject private var photoManager: PhotoManager
    @Environment(\.dismiss) private var dismiss
    let selectedIdentifier: String?
    let onSelect: (String) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 3
    )

    var body: some View {
        Group {
            if photoManager.petPhotos.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("No scanned pet photos yet")
                        .font(.title2.bold())
                    Text("Scan photos from the Library tab first, or choose directly from your photo library on the previous screen.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(photoManager.petPhotos) { photo in
                            Button {
                                onSelect(photo.id)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    PhotoThumbnailView(photo: photo)

                                    if selectedIdentifier == photo.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .blue)
                                            .padding(6)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .navigationTitle("Scanned Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
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
            ) { result, info in
                guard !hasResumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil
                guard !isDegraded || isCancelled || hasError else { return }
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
        case .neutral: return "Not set"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
