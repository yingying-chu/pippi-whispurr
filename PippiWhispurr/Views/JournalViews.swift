//
//  JournalViews.swift
//  PippiWhispurr
//
//  Manual journal entries and on-device photo-based writing suggestions.
//

import SwiftUI
import Photos
import PhotosUI
import UIKit
import CoreLocation

private struct JournalSuggestion: Identifiable {
    let id: String
    let title: String
    let prompt: String
    let date: Date
    let photoIdentifiers: [String]
    let petIDs: Set<UUID>
    let petNames: [String]
    let kind: MemoryEntry.Kind
    let coordinate: CLLocationCoordinate2D?
    let locationName: String?
}

private struct JournalEditorRequest: Identifiable {
    let id = UUID()
    let suggestion: JournalSuggestion?
}

struct JournalView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @EnvironmentObject private var photoManager: PhotoManager
    @State private var editorRequest: JournalEditorRequest?
    @State private var resolvedPlaceNames: [String: String] = [:]

    private var suggestions: [JournalSuggestion] {
        let usedPhotoIDs = Set(storyStore.memories.flatMap(\.photoIdentifiers))
        let candidates = photoManager.petPhotos.filter { !usedPhotoIDs.contains($0.id) }
        return eventClusters(from: candidates)
            .filter { $0.count >= 2 }
            .sorted { ($0.first?.date ?? .distantPast) > ($1.first?.date ?? .distantPast) }
            .compactMap { photos in
                let date = photos.first?.date ?? Date()
                let photoIDs = photos.map(\.id)
                let petIDs = Set(
                    storyStore.photos
                        .filter { photoIDs.contains($0.assetIdentifier) }
                        .flatMap(\.assignedPetIDs)
                )
                let petNames = storyStore.pets
                    .filter { petIDs.contains($0.id) }
                    .map(\.name)
                let milestone = milestoneDetails(for: date, petIDs: petIDs)
                let semantic = semanticSuggestion(for: photos, petNames: petNames)
                guard milestone != nil || semantic != nil else { return nil }
                let coordinate = representativeCoordinate(for: photos)

                return JournalSuggestion(
                    id: "event-\(date.timeIntervalSince1970)-\(photoIDs.first ?? "")",
                    title: milestone?.title ?? semantic?.title ?? "",
                    prompt: milestone?.prompt ?? semantic?.prompt ?? "",
                    date: date,
                    photoIdentifiers: photoIDs,
                    petIDs: petIDs,
                    petNames: petNames,
                    kind: milestone?.kind ?? semantic?.kind ?? .everyday,
                    coordinate: coordinate,
                    locationName: nil
                )
            }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested for You")
                                .font(.title2)
                                .fontWeight(.bold)

                            ForEach(suggestions) { suggestion in
                                Button {
                                    editorRequest = JournalEditorRequest(
                                        suggestion: resolvedSuggestion(suggestion)
                                    )
                                } label: {
                                    JournalSuggestionCard(
                                        suggestion: resolvedSuggestion(suggestion)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Journal")
                            .font(.title2)
                            .fontWeight(.bold)

                        if storyStore.memories.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 42))
                                    .foregroundColor(.secondary)
                                Text("Write the first entry")
                                    .font(.headline)
                                Text("A birthday, a park trip, or one tiny thing you don't want to forget.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .padding(.horizontal)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                        } else {
                            ForEach(memorySections) { section in
                                Text(section.title)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.top, 6)

                                ForEach(section.memories) { memory in
                                    NavigationLink(destination: JournalDetailView(memoryID: memory.id)) {
                                        JournalEntryRow(memory: memory)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editorRequest = JournalEditorRequest(suggestion: nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Journal Entry")
                }
            }
            .sheet(item: $editorRequest) { request in
                NavigationView {
                    JournalEditorView(suggestion: request.suggestion)
                }
            }
            .task(id: suggestions.map(\.id).joined(separator: "|")) {
                await resolveSuggestionPlaces()
            }
        }
        .navigationViewStyle(.stack)
    }

    private var memorySections: [JournalMonthSection] {
        let grouped = Dictionary(grouping: storyStore.memories) { memory in
            Calendar.current.dateInterval(of: .month, for: memory.memoryDate)?.start
                ?? Calendar.current.startOfDay(for: memory.memoryDate)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { month, memories in
                JournalMonthSection(
                    month: month,
                    title: month.formatted(.dateTime.month(.wide).year()),
                    memories: memories.sorted { $0.memoryDate > $1.memoryDate }
                )
            }
    }

    private func eventClusters(from photos: [PetPhoto]) -> [[PetPhoto]] {
        let sorted = photos.sorted { $0.date < $1.date }
        var clusters: [[PetPhoto]] = []

        for photo in sorted {
            guard let lastPhoto = clusters.last?.last else {
                clusters.append([photo])
                continue
            }

            let timeGap = photo.date.timeIntervalSince(lastPhoto.date)
            let sameDay = Calendar.current.isDate(photo.date, inSameDayAs: lastPhoto.date)
            let closeEnough: Bool
            if let firstLocation = lastPhoto.asset.location,
               let secondLocation = photo.asset.location {
                closeEnough = firstLocation.distance(from: secondLocation) <= 20_000
            } else {
                closeEnough = true
            }

            if sameDay && timeGap <= 4 * 60 * 60 && closeEnough {
                clusters[clusters.count - 1].append(photo)
            } else {
                clusters.append([photo])
            }
        }
        return clusters
    }

    private func milestoneDetails(
        for date: Date,
        petIDs: Set<UUID>
    ) -> (title: String, prompt: String, kind: MemoryEntry.Kind)? {
        let calendar = Calendar.current
        for pet in storyStore.pets where petIDs.contains(pet.id) {
            if let birthday = pet.birthday,
               calendar.component(.month, from: birthday) == calendar.component(.month, from: date),
               calendar.component(.day, from: birthday) == calendar.component(.day, from: date) {
                let age = calendar.dateComponents([.year], from: birthday, to: date).year ?? 0
                let title = age > 0 ? "\(pet.name)'s \(age.ordinal) Birthday" : "\(pet.name)'s Birthday"
                return (title, "What changed this year, and what made the celebration feel like \(pet.name)?", .birthday)
            }

            if let adoptionDate = pet.adoptionDate,
               calendar.component(.month, from: adoptionDate) == calendar.component(.month, from: date),
               calendar.component(.day, from: adoptionDate) == calendar.component(.day, from: date) {
                return ("\(pet.name)'s Adoption Anniversary", "What do you remember about finding each other?", .adoption)
            }
        }
        return nil
    }

    private func semanticSuggestion(
        for photos: [PetPhoto],
        petNames: [String]
    ) -> (title: String, prompt: String, kind: MemoryEntry.Kind)? {
        let labels = photos
            .flatMap(\.semanticLabels)
            .joined(separator: " ")
            .lowercased()
        let name = petNames.isEmpty ? nil : petNames.joined(separator: " & ")

        func containsAny(_ words: [String]) -> Bool {
            words.contains { labels.contains($0) }
        }

        if containsAny(["sleep", "nap", "bed", "bedding", "blanket", "pillow", "lying", "reclining", "resting"]) {
            return (
                name.map { "\($0)'s favorite way to nap" } ?? "A very serious nap",
                "Where did they settle down, and what made this moment especially cute?",
                .everyday
            )
        }
        if containsAny(["food", "meal", "eating", "feeding", "bowl", "snack", "drink", "tableware"]) {
            return (
                name.map { "Snack time with \($0)" } ?? "Snack time",
                "What were they eating, and did they have their usual reaction?",
                .everyday
            )
        }
        if containsAny(["toy", "playing", "play", "ball", "plush", "stuffed", "recreation"]) {
            return (
                name.map { "\($0) in play mode" } ?? "Play mode: on",
                "What game were they playing, and what happened next?",
                .everyday
            )
        }
        if containsAny(["walking", "hiking", "trail", "park", "grass", "outdoor", "leash", "sidewalk", "beach", "garden", "forest"]) {
            return (
                name.map { "\($0) out exploring" } ?? "Out exploring",
                "Where did you go, and what captured their attention?",
                .adventure
            )
        }
        if containsAny(["airplane", "aircraft", "airport", "luggage", "vehicle", "car"]) {
            return (
                name.map { "\($0)'s travel day" } ?? "A little travel adventure",
                "Where were you going, and how did they handle the journey?",
                .adventure
            )
        }
        if containsAny(["window"]) {
            return (
                name.map { "What caught \($0)'s eye?" } ?? "Something outside caught their eye",
                "What were they watching so carefully?",
                .everyday
            )
        }
        if containsAny(["portrait", "close-up", "closeup"]) {
            return (
                name.map { "\($0), up close" } ?? "That face, up close",
                "What expression or tiny detail made you take this photo?",
                .everyday
            )
        }
        return nil
    }

    private func representativeCoordinate(for photos: [PetPhoto]) -> CLLocationCoordinate2D? {
        photos.compactMap { $0.asset.location?.coordinate }.first
    }

    private func locationKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.3f,%.3f", coordinate.latitude, coordinate.longitude)
    }

    private func resolvedSuggestion(_ suggestion: JournalSuggestion) -> JournalSuggestion {
        guard let coordinate = suggestion.coordinate,
              let place = resolvedPlaceNames[locationKey(for: coordinate)] else {
            return suggestion
        }

        return JournalSuggestion(
            id: suggestion.id,
            title: suggestion.title,
            prompt: suggestion.prompt,
            date: suggestion.date,
            photoIdentifiers: suggestion.photoIdentifiers,
            petIDs: suggestion.petIDs,
            petNames: suggestion.petNames,
            kind: suggestion.kind,
            coordinate: suggestion.coordinate,
            locationName: place
        )
    }

    private func resolveSuggestionPlaces() async {
        let geocoder = CLGeocoder()
        for suggestion in suggestions {
            guard let coordinate = suggestion.coordinate else { continue }
            let key = locationKey(for: coordinate)
            guard resolvedPlaceNames[key] == nil else { continue }

            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(
                    CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                )
                guard let placemark = placemarks.first else { continue }
                let place = placemark.areasOfInterest?.first
                    ?? placemark.name
                    ?? placemark.locality
                if let place, !place.isEmpty {
                    resolvedPlaceNames[key] = place
                }
            } catch {
                continue
            }
        }
    }
}

private struct JournalMonthSection: Identifiable {
    let month: Date
    let title: String
    let memories: [MemoryEntry]
    var id: Date { month }
}

private struct JournalSuggestionCard: View {
    let suggestion: JournalSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            JournalPhotoCollage(identifiers: suggestion.photoIdentifiers)

            if let locationName = suggestion.locationName {
                Label(locationName, systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.green.opacity(0.12))
            }

            Text(suggestion.title)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            Text(suggestion.date.formatted(date: .long, time: .omitted))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 5)
            Text(suggestion.prompt)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }
}

private struct JournalEntryRow: View {
    let memory: MemoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !memory.photoIdentifiers.isEmpty {
                JournalPhotoCollage(identifiers: memory.photoIdentifiers)
            } else {
                Image(systemName: memory.kind?.systemImage ?? "book.closed")
                    .font(.system(size: 34))
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)
                    .background(Color.blue.opacity(0.1))
            }

            if let locationName = memory.locationName, !locationName.isEmpty {
                Label(locationName, systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.orange.opacity(0.11))
            }

            Text(memory.title.isEmpty ? memory.kind?.displayName ?? "A memory" : memory.title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            Text(memory.memoryDate.formatted(date: .long, time: .omitted))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 5)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
    }
}

private struct JournalPhotoCollage: View {
    let identifiers: [String]

    private var visibleIdentifiers: [String] {
        Array(identifiers.prefix(4))
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 2),
            spacing: 3
        ) {
            ForEach(Array(visibleIdentifiers.enumerated()), id: \.element) { index, identifier in
                ZStack(alignment: .bottomTrailing) {
                    AssetThumbnailView(identifier: identifier)
                        .frame(height: visibleIdentifiers.count <= 2 ? 170 : 105)

                    if index == visibleIdentifiers.count - 1 && identifiers.count > 4 {
                        Text("+\(identifiers.count - 4)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(10)
                            .padding(8)
                    }
                }
            }
        }
    }
}

struct NewJournalEntryView: View {
    let title: String
    let date: Date
    let petIDs: Set<UUID>
    let photoIdentifiers: [String]

    init(
        title: String = "",
        date: Date = Date(),
        petIDs: Set<UUID> = [],
        photoIdentifiers: [String] = []
    ) {
        self.title = title
        self.date = date
        self.petIDs = petIDs
        self.photoIdentifiers = photoIdentifiers
    }

    var body: some View {
        JournalEditorView(
            initialTitle: title,
            initialDate: date,
            initialPetIDs: petIDs,
            initialPhotoIdentifiers: photoIdentifiers
        )
    }
}

struct JournalEditorView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @Environment(\.dismiss) private var dismiss

    private let existingMemory: MemoryEntry?
    @State private var title: String
    @State private var bodyText: String
    @State private var date: Date
    @State private var petIDs: Set<UUID>
    @State private var photoIdentifiers: [String]
    @State private var kind: MemoryEntry.Kind
    @State private var feeling: MemoryEntry.Feeling?
    @State private var locationName: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingScannedPhotoPicker = false
    @State private var showsDetails = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case story
    }

    fileprivate init(
        existingMemory: MemoryEntry? = nil,
        suggestion: JournalSuggestion? = nil,
        initialTitle: String = "",
        initialDate: Date = Date(),
        initialPetIDs: Set<UUID> = [],
        initialPhotoIdentifiers: [String] = []
    ) {
        self.existingMemory = existingMemory
        _title = State(initialValue: existingMemory?.title ?? suggestion?.title ?? initialTitle)
        _bodyText = State(initialValue: existingMemory?.body ?? "")
        _date = State(initialValue: existingMemory?.memoryDate ?? suggestion?.date ?? initialDate)
        _petIDs = State(initialValue: existingMemory?.petIDs ?? suggestion?.petIDs ?? initialPetIDs)
        _photoIdentifiers = State(
            initialValue: existingMemory?.photoIdentifiers ?? suggestion?.photoIdentifiers ?? initialPhotoIdentifiers
        )
        _kind = State(initialValue: existingMemory?.kind ?? suggestion?.kind ?? .everyday)
        _feeling = State(initialValue: existingMemory?.feeling)
        _locationName = State(initialValue: existingMemory?.locationName ?? suggestion?.locationName)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose the moments")
                        .font(.title2.bold())

                    if photoIdentifiers.isEmpty {
                        Button {
                            focusedField = nil
                            showingScannedPhotoPicker = true
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 36))
                                    .foregroundColor(.orange)
                                Text("Choose Scanned Photos")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Start with photos. Words can come later.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 210)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(18)
                        }
                        .buttonStyle(.plain)
                    } else {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2),
                            spacing: 6
                        ) {
                            ForEach(photoIdentifiers, id: \.self) { identifier in
                                ZStack(alignment: .topTrailing) {
                                    AssetThumbnailView(identifier: identifier)
                                        .aspectRatio(1, contentMode: .fit)

                                    Button {
                                        photoIdentifiers.removeAll { $0 == identifier }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.65))
                                    }
                                    .padding(7)
                                }
                            }
                        }

                        Button {
                            focusedField = nil
                            showingScannedPhotoPicker = true
                        } label: {
                            Label("Add Scanned Photos", systemImage: "plus")
                        }
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 20,
                        matching: .images
                    ) {
                        Label("Choose from Photo Library Instead", systemImage: "photo.on.rectangle")
                            .font(.subheadline)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    TextField("Give this moment a name (optional)", text: $title)
                        .font(.title2.bold())
                        .focused($focusedField, equals: .title)

                    Text(writingPrompt)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextEditor(text: $bodyText)
                        .focused($focusedField, equals: .story)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 110)
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                        .overlay(alignment: .topLeading) {
                            if bodyText.isEmpty && focusedField != .story {
                                Text("Add one little thing you want to remember…")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    HStack {
                        Label("Date", systemImage: "calendar")
                            .foregroundColor(.secondary)
                        Spacer()
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }

                    if !storyStore.pets.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(storyStore.pets) { pet in
                                    Button {
                                        togglePet(pet.id)
                                    } label: {
                                        Label(
                                            pet.name,
                                            systemImage: petIDs.contains(pet.id) ? "checkmark.circle.fill" : "circle"
                                        )
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .foregroundColor(petIDs.contains(pet.id) ? .white : .primary)
                                        .background(petIDs.contains(pet.id) ? Color.blue : Color(.secondarySystemFill))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                DisclosureGroup(isExpanded: $showsDetails) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Type")
                            Spacer()
                            Picker("Type", selection: $kind) {
                                ForEach(MemoryEntry.Kind.allCases, id: \.self) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .labelsHidden()
                        }

                        Divider()

                        HStack {
                            Text("Feeling")
                            Spacer()
                            Picker("Feeling", selection: $feeling) {
                                Text("Not set").tag(MemoryEntry.Feeling?.none)
                                ForEach(MemoryEntry.Feeling.allCases, id: \.self) { option in
                                    Text(option.displayName).tag(MemoryEntry.Feeling?.some(option))
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    .padding(.top, 12)
                } label: {
                    Label("Optional details", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(existingMemory == nil ? "New Story" : "Edit Story")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingScannedPhotoPicker) {
            NavigationView {
                JournalScannedPhotoPicker(
                    initialSelection: Set(photoIdentifiers)
                ) { identifiers in
                    photoIdentifiers = identifiers
                }
            }
        }
        .onChange(of: selectedPhotoItems) { items in
            let newIdentifiers = items.compactMap(\.itemIdentifier)
            for identifier in newIdentifiers where !photoIdentifiers.contains(identifier) {
                photoIdentifiers.append(identifier)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(
                        photoIdentifiers.isEmpty
                            && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }

    private var writingPrompt: String {
        switch kind {
        case .birthday: return "What changed this year? What little habit feels especially like them now?"
        case .adoption: return "What do you remember about the day you found each other?"
        case .adventure: return "Where did you go, who came along, and what surprised you?"
        case .firstTime: return "What was new, and how did your pet respond?"
        case .health: return "What happened, how did your pet feel, and what helped?"
        case .everyday: return "What happened today? Include one small detail you don't want to forget."
        case .custom: return "Tell the story in your own way."
        }
    }

    private func togglePet(_ petID: UUID) {
        if petIDs.contains(petID) {
            petIDs.remove(petID)
        } else {
            petIDs.insert(petID)
        }
    }

    private func save() {
        let now = Date()
        storyStore.upsertMemory(MemoryEntry(
            id: existingMemory?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            memoryDate: date,
            petIDs: petIDs,
            photoIdentifiers: photoIdentifiers,
            locationName: locationName,
            kind: kind,
            feeling: feeling,
            createdAt: existingMemory?.createdAt ?? now,
            updatedAt: now
        ))
        dismiss()
    }
}

private struct JournalScannedPhotoPicker: View {
    @EnvironmentObject private var photoManager: PhotoManager
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String>
    let onDone: ([String]) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 3)

    init(initialSelection: Set<String>, onDone: @escaping ([String]) -> Void) {
        _selection = State(initialValue: initialSelection)
        self.onDone = onDone
    }

    var body: some View {
        Group {
            if photoManager.petPhotos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                    Text("No scanned photos yet")
                        .font(.title2.bold())
                    Text("Scan your Library first, or choose from the photo library on the previous screen.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 5) {
                        ForEach(photoManager.petPhotos) { photo in
                            Button {
                                toggle(photo.id)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    PhotoThumbnailView(photo: photo)

                                    Image(systemName: selection.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, selection.contains(photo.id) ? .blue : .black.opacity(0.45))
                                        .padding(6)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }
            }
        }
        .navigationTitle("Choose Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    let ordered = photoManager.petPhotos
                        .map(\.id)
                        .filter { selection.contains($0) }
                    onDone(ordered)
                    dismiss()
                }
            }
        }
    }

    private func toggle(_ identifier: String) {
        if selection.contains(identifier) {
            selection.remove(identifier)
        } else {
            selection.insert(identifier)
        }
    }
}

struct JournalDetailView: View {
    @EnvironmentObject private var storyStore: StoryStore
    let memoryID: UUID
    @State private var showingEditor = false

    private var memory: MemoryEntry? {
        storyStore.memories.first { $0.id == memoryID }
    }

    var body: some View {
        Group {
            if let memory {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !memory.photoIdentifiers.isEmpty {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible()), count: 2),
                                spacing: 8
                            ) {
                                ForEach(memory.photoIdentifiers, id: \.self) { identifier in
                                    AssetThumbnailView(identifier: identifier)
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }

                        Text(memory.title.isEmpty ? memory.kind?.displayName ?? "A memory" : memory.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        HStack(spacing: 12) {
                            Label(
                                memory.memoryDate.formatted(date: .long, time: .omitted),
                                systemImage: "calendar"
                            )
                            if let feeling = memory.feeling {
                                Label(feeling.displayName, systemImage: "heart")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                        if !memory.body.isEmpty {
                            Text(memory.body)
                                .font(.body)
                                .lineSpacing(5)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .navigationTitle("Journal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") { showingEditor = true }
                    }
                }
                .sheet(isPresented: $showingEditor) {
                    NavigationView {
                        JournalEditorView(existingMemory: memory)
                    }
                }
            } else {
                Text("This journal entry is no longer available.")
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct AssetThumbnailView: View {
    let identifier: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.15))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
            }
        }
        .clipped()
        .cornerRadius(10)
        .task(id: identifier) {
            await loadImage()
        }
    }

    private func loadImage() async {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true

        image = await withCheckedContinuation { continuation in
            var hasResumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1000, height: 1000),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil
                guard !isDegraded || isCancelled || hasError else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
    }
}

extension MemoryEntry.Kind {
    var displayName: String {
        switch self {
        case .everyday: return "Everyday"
        case .birthday: return "Birthday"
        case .adoption: return "Adoption"
        case .adventure: return "Adventure"
        case .firstTime: return "First Time"
        case .health: return "Health"
        case .custom: return "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .everyday: return "sun.max"
        case .birthday: return "birthday.cake"
        case .adoption: return "house"
        case .adventure: return "map"
        case .firstTime: return "sparkles"
        case .health: return "cross.case"
        case .custom: return "square.and.pencil"
        }
    }
}

private extension MemoryEntry.Feeling {
    var displayName: String {
        rawValue.capitalized
    }
}

private extension Int {
    var ordinal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
