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

private struct JournalSuggestion: Identifiable {
    let id: String
    let title: String
    let prompt: String
    let date: Date
    let photoIdentifiers: [String]
    let petIDs: Set<UUID>
    let kind: MemoryEntry.Kind
}

private struct JournalEditorRequest: Identifiable {
    let id = UUID()
    let suggestion: JournalSuggestion?
}

struct JournalView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @EnvironmentObject private var photoManager: PhotoManager
    @State private var editorRequest: JournalEditorRequest?

    private var suggestions: [JournalSuggestion] {
        let usedPhotoIDs = Set(storyStore.memories.flatMap(\.photoIdentifiers))
        let candidates = photoManager.petPhotos.filter { !usedPhotoIDs.contains($0.id) }
        let grouped = Dictionary(grouping: candidates) {
            Calendar.current.startOfDay(for: $0.date)
        }

        return grouped
            .filter { $0.value.count >= 2 }
            .sorted { $0.key > $1.key }
            .prefix(5)
            .map { date, photos in
                let photoIDs = photos.map(\.id)
                let petIDs = Set(
                    storyStore.photos
                        .filter { photoIDs.contains($0.assetIdentifier) }
                        .flatMap(\.assignedPetIDs)
                )
                let petNames = storyStore.pets
                    .filter { petIDs.contains($0.id) }
                    .map(\.name)
                let title = petNames.isEmpty
                    ? "A day with \(photos.count) pet moments"
                    : "A day with \(petNames.joined(separator: " & "))"

                return JournalSuggestion(
                    id: "day-\(date.timeIntervalSince1970)",
                    title: title,
                    prompt: "What happened around these photos? What made this day feel different?",
                    date: date,
                    photoIdentifiers: photoIDs,
                    petIDs: petIDs,
                    kind: .everyday
                )
            }
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
                                    editorRequest = JournalEditorRequest(suggestion: suggestion)
                                } label: {
                                    JournalSuggestionCard(suggestion: suggestion)
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
                            ForEach(storyStore.memories) { memory in
                                NavigationLink(destination: JournalDetailView(memoryID: memory.id)) {
                                    JournalEntryRow(memory: memory)
                                }
                                .buttonStyle(.plain)
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
        }
        .navigationViewStyle(.stack)
    }
}

private struct JournalSuggestionCard: View {
    let suggestion: JournalSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Array(suggestion.photoIdentifiers.prefix(4)), id: \.self) { identifier in
                    AssetThumbnailView(identifier: identifier)
                        .frame(height: 76)
                }
            }

            Text(suggestion.title)
                .font(.headline)
            Text(suggestion.date.formatted(date: .long, time: .omitted))
                .font(.caption)
                .foregroundColor(.secondary)
            Text(suggestion.prompt)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

private struct JournalEntryRow: View {
    let memory: MemoryEntry

    var body: some View {
        HStack(spacing: 14) {
            if let identifier = memory.photoIdentifiers.first {
                AssetThumbnailView(identifier: identifier)
                    .frame(width: 76, height: 76)
            } else {
                Image(systemName: memory.kind?.systemImage ?? "book.closed")
                    .font(.title2)
                    .frame(width: 76, height: 76)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(memory.title.isEmpty ? memory.kind?.displayName ?? "A memory" : memory.title)
                    .font(.headline)
                Text(memory.memoryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !memory.body.isEmpty {
                    Text(memory.body)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
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
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

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
    }

    var body: some View {
        Form {
            Section("Memory") {
                TextField("Title", text: $title)
                DatePicker("Date", selection: $date, displayedComponents: .date)

                Picker("Type", selection: $kind) {
                    ForEach(MemoryEntry.Kind.allCases, id: \.self) { option in
                        Label(option.displayName, systemImage: option.systemImage)
                            .tag(option)
                    }
                }

                Picker("Feeling", selection: $feeling) {
                    Text("Not set").tag(MemoryEntry.Feeling?.none)
                    ForEach(MemoryEntry.Feeling.allCases, id: \.self) { option in
                        Text(option.displayName).tag(MemoryEntry.Feeling?.some(option))
                    }
                }
            }

            if !storyStore.pets.isEmpty {
                Section("Pets in this memory") {
                    ForEach(storyStore.pets) { pet in
                        Button {
                            togglePet(pet.id)
                        } label: {
                            HStack {
                                Text(pet.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: petIDs.contains(pet.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(petIDs.contains(pet.id) ? .blue : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Photos") {
                if !photoIdentifiers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(photoIdentifiers, id: \.self) { identifier in
                                ZStack(alignment: .topTrailing) {
                                    AssetThumbnailView(identifier: identifier)
                                        .frame(width: 88, height: 88)

                                    Button {
                                        photoIdentifiers.removeAll { $0 == identifier }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.55), in: Circle())
                                    }
                                    .padding(4)
                                }
                            }
                        }
                    }
                }

                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                }
            }

            Section {
                Text(writingPrompt)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $bodyText)
                    .frame(minHeight: 180)
            } header: {
                Text("Your story")
            }
        }
        .navigationTitle(existingMemory == nil ? "New Entry" : "Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItems) { items in
            let newIdentifiers = items.compactMap(\.itemIdentifier)
            photoIdentifiers = Array(Set(photoIdentifiers + newIdentifiers))
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            locationName: existingMemory?.locationName,
            kind: kind,
            feeling: feeling,
            createdAt: existingMemory?.createdAt ?? now,
            updatedAt: now
        ))
        dismiss()
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
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        image = await withCheckedContinuation { continuation in
            var hasResumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 400, height: 400),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
    }
}

private extension MemoryEntry.Kind {
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
