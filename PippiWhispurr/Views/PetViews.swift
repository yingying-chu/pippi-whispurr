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
    @State private var profileScrollOffset: CGFloat = 0

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
                            .frame(height: petSwitcherHeight, alignment: .top)
                            .opacity(petSwitcherHeight / 104)
                            .clipped()
                        Divider()
                    }

                    PetProfileView(
                        petID: activePetID,
                        onScrollOffset: { offset in profileScrollOffset = offset },
                        onAddPet: { showingNewPet = true }
                    )
                }
            }
        }
        .navigationBarHidden(true)
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

    private var petSwitcherHeight: CGFloat {
        max(0, min(104, 104 + profileScrollOffset))
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
            HStack(spacing: 10) {
                ForEach(storyStore.pets) { pet in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPetID = pet.id
                        }
                    } label: {
                        VStack(spacing: 6) {
                            PetProfileImageView(
                                assetIdentifier: pet.profilePhotoIdentifier,
                                size: 50,
                                fallback: speciesEmoji(for: pet)
                            )
                            .overlay {
                                if activePetID == pet.id {
                                    Circle().stroke(Color.honeyYellow, lineWidth: 3)
                                }
                            }

                            Text(pet.name)
                                .font(.pippi(11, weight: activePetID == pet.id ? .semibold : .regular))
                                .foregroundColor(activePetID == pet.id ? .cream : .forestInk)
                        }
                        .frame(minWidth: 72)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(activePetID == pet.id ? Color.forestInk : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: .radiusCard, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showingNewPet = true
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 50, height: 50)
                            .background(Color.forestInk.opacity(0.08))
                            .clipShape(Circle())
                        Text("Add")
                            .font(.pippi(11))
                            .foregroundColor(.forestInk.opacity(0.65))
                    }
                    .frame(minWidth: 72)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.cream)
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
                .foregroundColor(.forestInk)

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
            .buttonStyle(PippiPrimaryButtonStyle())
        }
        .padding()
    }
}

struct PetProfileView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @EnvironmentObject private var photoManager: PhotoManager
    let petID: UUID
    var onScrollOffset: (CGFloat) -> Void = { _ in }
    var onAddPet: () -> Void = {}
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

    private var petMilestones: [Milestone] {
        storyStore.milestones
            .filter { $0.petID == petID }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if let pet {
                ScrollView {
                    VStack(spacing: 16) {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: VerticalScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("petProfileScroll")).minY
                            )
                        }
                        .frame(height: 0)

                        ZStack(alignment: .bottomLeading) {
                            PetProfileImageView(
                                assetIdentifier: pet.profilePhotoIdentifier,
                                size: UIScreen.main.bounds.width,
                                fallback: speciesEmoji(for: pet),
                                isCircular: false
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .clipped()

                            LinearGradient(
                                colors: [.forestInk.opacity(0.45), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                            .frame(maxWidth: .infinity, maxHeight: 280)
                            .allowsHitTesting(false)

                            LinearGradient(
                                colors: [.clear, .forestInk.opacity(0.75)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .frame(maxWidth: .infinity, maxHeight: 280)
                            .allowsHitTesting(false)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(pet.name)
                                    .font(.pippi(32, weight: .extraBold))
                                    .foregroundColor(.forestInk)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.honeyYellow)
                                    .cornerRadius(4)

                                Text(profileSubtitle(for: pet))
                                    .font(.pippiScript(14))
                                    .italic()
                                    .foregroundColor(.white.opacity(0.88))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Color.forestInk.opacity(0.65))
                                    .clipShape(Capsule())
                            }
                            .padding(16)

                            VStack {
                                HStack(spacing: 8) {
                                    Spacer()
                                    Button(action: onAddPet) {
                                        Image(systemName: "plus")
                                            .font(.subheadline.bold())
                                            .frame(width: 36, height: 36)
                                            .background(Color.cream.opacity(0.92))
                                            .foregroundColor(.forestInk)
                                            .clipShape(Circle())
                                    }
                                    Button {
                                        showingEditor = true
                                    } label: {
                                        Label("EDIT", systemImage: "pencil")
                                            .font(.pippi(10, weight: .semibold))
                                            .tracking(1)
                                            .padding(.horizontal, 12)
                                            .frame(height: 36)
                                            .background(Color.cream.opacity(0.92))
                                            .foregroundColor(.forestInk)
                                            .clipShape(Capsule())
                                    }
                                }
                                Spacer()
                            }
                            .padding(14)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, -16)

                        profileStats

                        VStack(alignment: .leading, spacing: 10) {
                            Text("TIMELINE · \(timelineDateLabel)")
                                .font(.pippi(10, weight: .semibold))
                                .tracking(1.8)
                                .foregroundColor(.forestInk.opacity(0.45))

                            timelineStrip
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if !pet.introduction.isEmpty {
                            Text(pet.introduction)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .pippiCard()
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("STORIES")
                                    .font(.pippi(10, weight: .semibold))
                                    .tracking(1.8)
                                    .foregroundColor(.forestInk.opacity(0.45))
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
                                    .pippiCard()
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
                                                .foregroundColor(.forestInk.opacity(0.5))
                                        }
                                        .padding()
                                        .pippiCard()
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button {
                            showingJournalEditor = true
                        } label: {
                            HStack(spacing: 7) {
                                Text("→")
                                Text("RECORD A STORY")
                                    .tracking(1.3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PippiPrimaryButtonStyle())

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
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: .radiusCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: .radiusCard, style: .continuous)
                                .stroke(Color.forestInk.opacity(0.08), lineWidth: 1)
                        )

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
                .coordinateSpace(name: "petProfileScroll")
                .onPreferenceChange(VerticalScrollOffsetPreferenceKey.self) { offset in
                    onScrollOffset(offset)
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

    private var profileStats: some View {
        HStack(spacing: 8) {
            profileStat(value: assignedPhotos.count, label: "PHOTOS", highlighted: false)
            profileStat(value: recentMemories.count, label: "MEMORIES", highlighted: true)
            profileStat(value: petMilestones.count, label: "MILESTONES", highlighted: false)
        }
    }

    private func profileStat(value: Int, label: String, highlighted: Bool) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.pippi(24, weight: .extraBold))
                .foregroundColor(.forestInk)
            Text(label)
                .font(.pippi(8, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.forestInk.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(highlighted ? Color.honeyYellow : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: .radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusCard, style: .continuous)
                .stroke(Color.forestInk.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: -3, y: 4)
    }

    @ViewBuilder
    private var timelineStrip: some View {
        HStack(spacing: 6) {
            if assignedPhotos.isEmpty {
                timelinePlaceholder(color: Color.mintSage.opacity(0.55))
                timelinePlaceholder(color: Color.honeyYellow)
                timelinePlaceholder(color: Color.stickyLavender.opacity(0.75))
            } else {
                ForEach(Array(assignedPhotos.prefix(3))) { photo in
                    NavigationLink(destination: PhotoDetailView(photo: photo, photos: assignedPhotos)) {
                        PhotoThumbnailView(photo: photo)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: .radiusPhoto))
                    }
                }
            }
        }
    }

    private func timelinePlaceholder(color: Color) -> some View {
        RoundedRectangle(cornerRadius: .radiusPhoto, style: .continuous)
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: .radiusPhoto, style: .continuous)
                    .stroke(Color.forestInk.opacity(0.08), lineWidth: 1)
            )
    }

    private var timelineDateLabel: String {
        let date = assignedPhotos.first?.date
            ?? recentMemories.first?.memoryDate
            ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).day())
            .uppercased()
    }

    private func profileSubtitle(for pet: PetProfile) -> String {
        let identity: String
        if let breed = pet.breed?.trimmingCharacters(in: .whitespacesAndNewlines),
           !breed.isEmpty {
            identity = breed
        } else {
            identity = pet.species
        }

        guard let age = ageDescription(from: pet.birthday) else {
            return identity
        }
        return "\(identity) · \(age)"
    }

    private func ageDescription(from birthday: Date?) -> String? {
        guard let birthday, birthday <= Date() else { return nil }
        let components = Calendar.current.dateComponents([.year, .month], from: birthday, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0
        if years > 0 {
            return years == 1 ? "1 year old" : "\(years) years old"
        }
        return months == 1 ? "1 month old" : "\(months) months old"
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
                            .buttonStyle(PippiPrimaryButtonStyle())

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

                Toggle("Add a Together Since date", isOn: $hasAdoptionDate)
                if hasAdoptionDate {
                    DatePicker("Together Since", selection: $adoptionDate, displayedComponents: .date)
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
    @State private var scanAttempted = false
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
                    Text(scanAttempted ? "No Pet Matches Found" : "No Scanned Pet Photos Yet")
                        .font(.title2.bold())
                    Text(scanAttempted
                         ? "PiPi checked the available photos but did not find a pet match. You can still choose any photo from the previous screen."
                         : "Scan your photo library here, then choose a pet photo without leaving this page.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    Button {
                        scanAttempted = true
                        Task { await photoManager.scanAllRemainingPhotos() }
                    } label: {
                        if photoManager.isScanning {
                            HStack(spacing: 10) {
                                ProgressView().tint(.cream)
                                Text("SCANNING \(photoManager.scannedPhotosCount) / \(photoManager.totalPhotosToScan)")
                            }
                        } else {
                            Label("SCAN PHOTOS NOW", systemImage: "magnifyingglass")
                        }
                    }
                    .buttonStyle(PippiPrimaryButtonStyle())
                    .disabled(photoManager.isScanning)
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
        .task {
            await photoManager.prepareScanSummary()
        }
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
    var isCircular = true
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isCircular ? size / 2 : 0, style: .continuous)
                .fill(Color.forestInk.opacity(0.12))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: isCircular ? size / 2 : 0,
                            style: .continuous
                        )
                    )
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
