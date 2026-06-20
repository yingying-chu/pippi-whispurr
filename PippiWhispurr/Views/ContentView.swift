//
//  ContentView.swift
//  PippiWhispurr
//
//  Main product navigation and story-focused home.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    private enum AppTab: Hashable {
        case home
        case pets
        case library
        case journal
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                openLibrary: { selectedTab = .library }
            )
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
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject private var storyStore: StoryStore
    @EnvironmentObject private var photoManager: PhotoManager
    @State private var showingNewPet = false
    let openLibrary: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if storyStore.pets.isEmpty {
                        discoveryWelcome
                    } else {
                        storyHome
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("PiPi")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewPet) {
                NavigationView {
                    PetEditorView()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var discoveryWelcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Find the story already in your photos")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("PiPi finds pet moments privately on your phone. You can name and organize each pet whenever you're ready.")
                    .foregroundColor(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.blue.opacity(0.1))
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 72))
                    .foregroundColor(.blue)
            }
            .frame(height: 220)

            Button(action: openLibrary) {
                Label("Find My Pet Photos", systemImage: "sparkle.magnifyingglass")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("I want to add a pet first") {
                showingNewPet = true
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var storyHome: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                Text("Every day with them has a story")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Keep the funny habits, everyday adventures, and little moments that feel like them.")
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Your pets")
                    .font(.title2)
                    .fontWeight(.bold)

                ForEach(storyStore.pets) { pet in
                    NavigationLink(destination: PetProfileView(petID: pet.id)) {
                        HomePetCard(pet: pet)
                    }
                    .buttonStyle(.plain)
                }
            }

            photoLibraryButton
        }
    }

    private var photoLibraryButton: some View {
        Button(action: openLibrary) {
            HStack(spacing: 14) {
                Image(systemName: photoManager.petPhotos.isEmpty ? "photo.badge.plus" : "photo.stack.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 3) {
                    Text(photoManager.petPhotos.isEmpty ? "Find pet photos" : "Open photo library")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(photoLibrarySubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    private var photoLibrarySubtitle: String {
        if photoManager.petPhotos.isEmpty {
            return "Scan when you're ready—your journal comes first."
        }
        return "\(photoManager.petPhotos.count) pet photos ready to organize"
    }
}

private struct HomePetCard: View {
    let pet: PetProfile

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                Text(speciesEmoji)
                    .font(.title)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text(pet.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(pet.introduction.isEmpty ? "Start building \(pet.name)'s story" : pet.introduction)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(18)
    }

    private var speciesEmoji: String {
        switch pet.species.lowercased() {
        case "dog": return "🐕"
        case "cat": return "🐈"
        default: return "🐾"
        }
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
