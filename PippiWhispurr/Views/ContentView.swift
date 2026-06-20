//
//  ContentView.swift
//  PippiWhispurr
//
//  Main product navigation and story-focused home.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject private var photoManager: PhotoManager
    @State private var selectedTab: AppTab = .home
    @State private var showingScanProgress = false

    private enum AppTab: Hashable {
        case home
        case pets
        case library
        case journal
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            NavigationView {
                PetListView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Pets", systemImage: "pawprint.fill")
            }
            .tag(AppTab.pets)

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "photo.on.rectangle.angled")
                }
                .tag(AppTab.library)

            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.closed.fill")
                }
            .tag(AppTab.journal)
        }
        .overlay(alignment: .bottom) {
            if photoManager.isScanning {
                Button {
                    showingScanProgress = true
                } label: {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Finding pet moments")
                                .font(.subheadline.weight(.semibold))
                            Text("\(photoManager.scannedPhotosCount.formatted()) of \(photoManager.totalPhotosToScan.formatted())")
                                .font(.caption)
                                .opacity(0.85)
                        }

                        Spacer()

                        Text("\(Int(photoManager.scanProgress * 100))%")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 52)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingScanProgress) {
            ScannerView()
        }
    }
}

// MARK: - Home

private struct HomeJournalSeed: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let petIDs: Set<UUID>
    let photoIdentifiers: [String]
}

struct HomeView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @EnvironmentObject private var photoManager: PhotoManager
    @State private var journalSeed: HomeJournalSeed?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingScanner = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    greeting
                    captureActions

                    if let suggestedSeed {
                        suggestionCard(suggestedSeed)
                    } else if let latestMemory = storyStore.memories.first {
                        recentMemoryCard(latestMemory)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle("PiPi")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $journalSeed, onDismiss: {
                selectedPhotoItems = []
            }) { seed in
                NavigationView {
                    NewJournalEntryView(
                        title: seed.title,
                        date: seed.date,
                        petIDs: seed.petIDs,
                        photoIdentifiers: seed.photoIdentifiers
                    )
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScannerView()
            }
            .onChange(of: selectedPhotoItems) { items in
                let identifiers = items.compactMap(\.itemIdentifier)
                guard !identifiers.isEmpty else { return }
                journalSeed = HomeJournalSeed(
                    title: "",
                    date: Date(),
                    petIDs: [],
                    photoIdentifiers: identifiers
                )
            }
        }
        .navigationViewStyle(.stack)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: greetingIcon)
                    .font(.title2)
                    .foregroundColor(.orange)
                Text(greetingText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text(homeQuestion)
                .font(.system(size: 38, weight: .bold, design: .rounded))

            Text(journalPrompt)
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }

    private var captureActions: some View {
        VStack(spacing: 14) {
            Button {
                journalSeed = HomeJournalSeed(
                    title: "",
                    date: Date(),
                    petIDs: [],
                    photoIdentifiers: []
                )
            } label: {
                Label("Add a Pet Moment", systemImage: "square.and.pencil")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    HomeSecondaryAction(
                        title: "Choose Photos",
                        systemImage: "photo.on.rectangle.angled"
                    )
                }

                Button {
                    showingScanner = true
                } label: {
                    HomeSecondaryAction(
                        title: "Scan Older Photos",
                        systemImage: "sparkle.magnifyingglass"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestedSeed: HomeJournalSeed? {
        let usedIDs = Set(storyStore.memories.flatMap(\.photoIdentifiers))
        let unused = photoManager.petPhotos.filter { !usedIDs.contains($0.id) }
        let groups = Dictionary(grouping: unused) {
            Calendar.current.startOfDay(for: $0.date)
        }
        guard let group = groups
            .filter({ $0.value.count >= 2 })
            .max(by: { $0.key < $1.key }) else {
            return nil
        }

        let photoIDs = group.value.map(\.id)
        let petIDs = Set(
            storyStore.photos
                .filter { photoIDs.contains($0.assetIdentifier) }
                .flatMap(\.assignedPetIDs)
        )
        return HomeJournalSeed(
            title: "A day worth remembering",
            date: group.key,
            petIDs: petIDs,
            photoIdentifiers: photoIDs
        )
    }

    private func suggestionCard(_ seed: HomeJournalSeed) -> some View {
        Button {
            journalSeed = seed
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("A moment worth writing")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(seed.photoIdentifiers.count) photos from \(seed.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.yellow.opacity(0.12))
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }

    private func recentMemoryCard(_ memory: MemoryEntry) -> some View {
        NavigationLink(destination: JournalDetailView(memoryID: memory.id)) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your latest memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(memory.title.isEmpty ? "A moment from today" : memory.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(memory.memoryDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }

    private var journalPrompt: String {
        "A photo and one small detail are enough."
    }

    private var petSubject: String {
        if storyStore.pets.count == 1, let pet = storyStore.pets.first {
            return pet.name
        }
        return "your pets"
    }

    private var homeQuestion: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<5:
            return "Still awake with \(petSubject)?"
        case 5..<10:
            return "What's on the morning agenda with \(petSubject)?"
        case 10..<13:
            return "Have you and \(petSubject) eaten yet?"
        case 13..<17:
            return "What have you and \(petSubject) been up to today?"
        case 17..<21:
            return "How has today felt with \(petSubject)?"
        default:
            return "Anything from today you want to keep?"
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Good morning"
        case 11..<14: return "It's lunchtime"
        case 14..<18: return "Good afternoon"
        case 18..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var greetingIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < 6 ? "moon.stars.fill" : "sun.max.fill"
    }
}

private struct HomeSecondaryAction: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.blue)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }
}

// MARK: - Library

struct LibraryView: View {
    private enum BrowseMode: String, CaseIterable {
        case photos = "Photos"
        case calendar = "Calendar"
        case map = "Map"
    }

    @EnvironmentObject private var photoManager: PhotoManager
    @State private var selectedDate: Date?
    @State private var showingScanner = false
    @State private var browseMode: BrowseMode = .photos

    var body: some View {
        NavigationView {
            Group {
                if photoManager.authorizationStatus == .notDetermined ||
                    photoManager.authorizationStatus == .denied {
                    PermissionView()
                } else if photoManager.petPhotos.isEmpty && !photoManager.isScanning {
                    EmptyStateView(showingScanner: $showingScanner)
                } else {
                    VStack(spacing: 0) {
                        Picker("Browse", selection: $browseMode) {
                            ForEach(BrowseMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        FilterBarView()

                        if browseMode == .photos {
                            RecentPhotosView()
                        } else if browseMode == .calendar {
                            CalendarView(selectedDate: $selectedDate)
                            Divider()
                            if let selectedDate {
                                PhotoGridView(date: selectedDate)
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.title)
                                    Text("Choose a highlighted day")
                                        .font(.headline)
                                    Text("Only days containing pet photos are selectable.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } else {
                            PhotoMapBrowserView(photos: photoManager.filteredPetPhotos)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingScanner = true
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Scan Photo Library")
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScannerView()
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Stats Header

struct StatsHeaderView: View {
    @EnvironmentObject var photoManager: PhotoManager

    var dogCount: Int { photoManager.petPhotos.filter { $0.petType == .dog }.count }
    var catCount: Int { photoManager.petPhotos.filter { $0.petType == .cat }.count }
    var otherCount: Int { photoManager.petPhotos.filter { $0.petType == .other }.count }
    var favoriteCount: Int { photoManager.favoriteIDs.count }

    var body: some View {
        HStack(spacing: 0) {
            StatPill(label: "Total", value: photoManager.petPhotos.count, color: .blue)
            StatPill(label: "🐕", value: dogCount, color: .orange)
            StatPill(label: "🐱", value: catCount, color: .purple)
            StatPill(label: "❤️", value: favoriteCount, color: .red)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }
}

struct StatPill: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Filter Bar

struct FilterBarView: View {
    @EnvironmentObject var photoManager: PhotoManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(
                    label: "All",
                    emoji: nil,
                    isSelected: photoManager.activeFilter == nil && !photoManager.showsFavoritesOnly
                ) {
                    photoManager.setFilter(nil)
                }
                FilterChip(label: "Dogs", emoji: "🐕", isSelected: photoManager.activeFilter == .dog) {
                    photoManager.setFilter(.dog)
                }
                FilterChip(label: "Cats", emoji: "🐱", isSelected: photoManager.activeFilter == .cat) {
                    photoManager.setFilter(.cat)
                }
                FilterChip(label: "Other", emoji: "🐾", isSelected: photoManager.activeFilter == .other) {
                    photoManager.setFilter(.other)
                }
                FilterChip(
                    label: "Favorites",
                    emoji: "❤️",
                    isSelected: photoManager.showsFavoritesOnly
                ) {
                    photoManager.showFavorites()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}

struct FilterChip: View {
    let label: String
    let emoji: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let emoji = emoji {
                    Text(emoji).font(.caption)
                }
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.blue : Color(.secondarySystemFill))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Permission / Empty

struct PermissionView: View {
    @EnvironmentObject var photoManager: PhotoManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text("Photo Library Access")
                .font(.title2)
                .fontWeight(.bold)

            Text("PiPi needs access to your photo library to scan and identify photos of your pets.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Grant Access") {
                Task { await photoManager.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct EmptyStateView: View {
    @Binding var showingScanner: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text("No Pet Photos Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Tap the button below to scan your photo library and find all your precious pet moments!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Scan Photo Library") {
                showingScanner = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Recent Photos

struct RecentPhotosView: View {
    @EnvironmentObject var photoManager: PhotoManager

    var recentPhotos: [PetPhoto] {
        photoManager.filteredPetPhotos
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(photoManager.showsFavoritesOnly ? "Favorite Photos" : "Pet Photos")
                        .font(.headline)
                    Spacer()
                    Text("\(recentPhotos.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                if recentPhotos.isEmpty {
                    Text("No photos match the current filter.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(recentPhotos) { photo in
                            NavigationLink(destination: PhotoDetailView(photo: photo)) {
                                PhotoThumbnailView(photo: photo)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let storyStore = StoryStore()
        ContentView()
            .environmentObject(PhotoManager())
            .environmentObject(storyStore)
    }
}
