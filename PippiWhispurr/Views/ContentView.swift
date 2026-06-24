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
    @EnvironmentObject private var storyStore: StoryStore
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
                    Label("Library", systemImage: "photo.stack.fill")
                }
                .tag(AppTab.library)

            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.closed.fill")
                }
            .tag(AppTab.journal)
        }
        .overlay(alignment: .bottom) {
            if photoManager.isScanning || photoManager.isScanPaused {
                Button {
                    showingScanProgress = true
                } label: {
                    HStack(spacing: 10) {
                        if photoManager.isScanning {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "pause.circle.fill")
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(photoManager.isScanPaused ? "Scan paused" : "Finding pet moments")
                                .font(.pippi(13, weight: .semibold))
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
                    .background(photoManager.isScanPaused ? Color.blobOrange : Color.forestInk)
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
                VStack(alignment: .leading, spacing: 18) {
                    homeHeader
                    greeting
                    captureActions

                    if let suggestedSeed {
                        suggestionCard(suggestedSeed)
                    } else if let latestMemory = storyStore.memories.first {
                        recentMemoryCard(latestMemory)
                    } else {
                        emptyFeaturedCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color.cream.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationTitle("")
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

    private var homeHeader: some View {
        HStack {
            Text("PiPi")
                .font(.pippi(28, weight: .extraBold))
                .foregroundColor(.forestInk)
            Spacer()
            Button {
                    journalSeed = HomeJournalSeed(
                        title: "",
                        date: Date(),
                        petIDs: [],
                        photoIdentifiers: []
                    )
            } label: {
                Text("DAILY LOG")
                    .font(.pippi(10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(.forestInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(Capsule().stroke(Color.forestInk.opacity(0.25), lineWidth: 1))
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: greetingIcon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.honeyYellow)
                Text(greetingText)
                    .font(.pippi(10, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(.forestInk.opacity(0.45))
            }

            highlightedHomeQuestion
                .font(.pippi(30, weight: .extraBold))
                .foregroundColor(.forestInk)
                .lineSpacing(-2)

            Text(journalPrompt)
                .font(.pippiScript(16))
                .foregroundColor(.forestInk.opacity(0.6))
        }
    }

    private var highlightedHomeQuestion: Text {
        var value = AttributedString(homeQuestion)
        if let lastWord = homeQuestion.split(separator: " ").last,
           let range = value.range(of: String(lastWord)) {
            value[range].backgroundColor = .honeyYellow
        }
        return Text(value)
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
                HStack(spacing: 7) {
                    Text("→")
                    Text("ADD A PET MOMENT")
                        .tracking(1.4)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PippiPrimaryButtonStyle())

            HStack(spacing: 10) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    HomeSecondaryAction(
                        title: "Add to Story",
                        systemImage: "camera.fill",
                        background: Color.mintSage.opacity(0.55)
                    )
                }

                Button {
                    showingScanner = true
                } label: {
                    HomeSecondaryAction(
                        title: "Find Pet Photos",
                        systemImage: "magnifyingglass",
                        background: Color.softTeal.opacity(0.55)
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
            featuredMomentContent(
                title: "A moment worth writing",
                detail: "\(seed.photoIdentifiers.count) photos · \(seed.date.formatted(.dateTime.month(.abbreviated).day()))"
            )
        }
        .buttonStyle(.plain)
    }

    private func recentMemoryCard(_ memory: MemoryEntry) -> some View {
        NavigationLink(destination: JournalDetailView(memoryID: memory.id)) {
            featuredMomentContent(
                title: memory.title.isEmpty ? "A moment worth keeping" : memory.title,
                detail: memory.memoryDate.formatted(.dateTime.month(.abbreviated).day())
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyFeaturedCard: some View {
        Button {
            journalSeed = HomeJournalSeed(
                title: "",
                date: Date(),
                petIDs: [],
                photoIdentifiers: []
            )
        } label: {
            featuredMomentContent(
                title: "A moment worth writing",
                detail: "Start today's story"
            )
        }
        .buttonStyle(.plain)
    }

    private func featuredMomentContent(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.honeyYellow)
                    .frame(width: 8, height: 8)
                Text("FEATURED MOMENT")
                    .font(.pippi(10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundColor(.forestInk.opacity(0.55))
            }
            Text(title)
                .font(.pippi(17, weight: .extraBold))
                .foregroundColor(.forestInk)
            Text(detail.uppercased())
                .font(.pippi(9, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.forestInk.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pippiCard()
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
    let background: Color

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.forestInk)
            Text(title.uppercased())
                .font(.pippi(10, weight: .semibold))
                .tracking(1.1)
                .foregroundColor(.forestInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: .radiusPill, style: .continuous))
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
    @EnvironmentObject private var storyStore: StoryStore
    @State private var selectedDate: Date?
    @State private var showingScanner = false
    @State private var browseMode: BrowseMode = .photos
    @State private var libraryScrollOffset: CGFloat = 0
    @State private var calendarCollapsed = false
    @State private var showingTodayMemory = false

    var body: some View {
        NavigationView {
            Group {
                if photoManager.authorizationStatus == .denied ||
                    photoManager.authorizationStatus == .restricted {
                    PermissionView()
                } else if photoManager.isRestoringLibrary {
                    LibraryRestoreView()
                } else if photoManager.petPhotos.isEmpty && !storyStore.photos.isEmpty {
                    LibraryRecoveryView(savedCount: storyStore.photos.count)
                } else if photoManager.petPhotos.isEmpty {
                    EmptyStateView(
                        showingScanner: $showingScanner,
                        hasSavedResults: photoManager.unavailableSavedPhotoCount > 0
                    )
                } else {
                    VStack(spacing: 0) {
                        Picker("Browse", selection: $browseMode) {
                            ForEach(BrowseMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        if browseMode == .photos {
                            FilterBarView()
                        }

                        if browseMode == .photos {
                            RecentPhotosView { offset in
                                libraryScrollOffset = offset
                            }
                        } else if browseMode == .calendar {
                            CalendarView(
                                selectedDate: $selectedDate,
                                isCollapsed: $calendarCollapsed,
                                onRecordToday: { showingTodayMemory = true }
                            )
                            if let selectedDate {
                                HStack {
                                    Text("\(selectedDate.formatted(.dateTime.month(.abbreviated).day()).uppercased()) · \(photoManager.filteredPhotosByDate[Calendar.current.startOfDay(for: selectedDate)]?.count ?? 0) PHOTOS")
                                        .font(.pippi(10, weight: .semibold))
                                        .tracking(1.4)
                                        .foregroundColor(.forestInk.opacity(0.7))
                                    Spacer()
                                    Text("ALL →")
                                        .font(.pippi(9, weight: .semibold))
                                        .tracking(1)
                                        .foregroundColor(.cream)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Color.forestInk)
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)

                                PhotoGridView(date: selectedDate) { offset in
                                    if offset < -18 {
                                        calendarCollapsed = true
                                    }
                                }
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
                    .background(Color.cream)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                libraryHeader
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingScanner) {
                ScannerView()
            }
            .sheet(isPresented: $showingTodayMemory) {
                NavigationView {
                    NewJournalEntryView(date: Date())
                }
            }
            .onAppear {
                UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.forestInk)
                UISegmentedControl.appearance().setTitleTextAttributes(
                    [.foregroundColor: UIColor(Color.cream)],
                    for: .selected
                )
                UISegmentedControl.appearance().setTitleTextAttributes(
                    [.foregroundColor: UIColor(Color.forestInk)],
                    for: .normal
                )
            }
        }
        .navigationViewStyle(.stack)
    }

    private var libraryHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Library")
                    .font(.pippi(28 - 8 * libraryHeaderCollapseProgress, weight: .extraBold))
                    .foregroundColor(.forestInk)
                Text("Pet moments, all together")
                    .font(.pippiScript(15))
                    .foregroundColor(.forestInk.opacity(0.55))
                    .opacity(1 - libraryHeaderCollapseProgress)
                    .frame(height: 18 * (1 - libraryHeaderCollapseProgress), alignment: .top)
            }
            Spacer()
            Button {
                showingScanner = true
            } label: {
                Label("ADD", systemImage: "photo.badge.plus")
            }
            .buttonStyle(PippiOutlineButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10 - 5 * libraryHeaderCollapseProgress)
        .background(Color.cream)
    }

    private var libraryHeaderCollapseProgress: CGFloat {
        min(1, max(0, -libraryScrollOffset / 64))
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
            StatPill(label: "Total", value: photoManager.petPhotos.count, isHighlighted: true)
            StatPill(label: "🐕", value: dogCount)
            StatPill(label: "🐱", value: catCount)
            StatPill(label: "❤️", value: favoriteCount)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }
}

struct StatPill: View {
    let label: String
    let value: Int
    var isHighlighted = false

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.pippi(18, weight: .extraBold))
                .foregroundColor(.forestInk)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(isHighlighted ? Color.honeyYellow : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: .radiusTag))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusTag)
                .stroke(Color.forestInk.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Filter Bar

struct FilterBarView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject private var storyStore: StoryStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(
                    label: "All",
                    emoji: nil,
                    isSelected: photoManager.activeFilter == nil &&
                        photoManager.activePetFilterID == nil &&
                        !photoManager.showsFavoritesOnly
                ) {
                    photoManager.setFilter(nil)
                }

                ForEach(storyStore.pets) { pet in
                    FilterChip(
                        label: pet.name,
                        emoji: petEmoji(pet),
                        isSelected: photoManager.activePetFilterID == pet.id
                    ) {
                        photoManager.setPetFilter(pet.id)
                    }
                }

                FilterChip(label: "Cats", emoji: "🐱", isSelected: photoManager.activeFilter == .cat) {
                    photoManager.setFilter(.cat)
                }
                FilterChip(label: "Dogs", emoji: "🐕", isSelected: photoManager.activeFilter == .dog) {
                    photoManager.setFilter(.dog)
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
        .background(Color.cream)
    }

    private func petEmoji(_ pet: PetProfile) -> String {
        switch pet.species.lowercased() {
        case "cat": return "🐱"
        case "dog": return "🐕"
        default: return "🐾"
        }
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
                    .font(.pippi(13, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.forestInk : Color.forestInk.opacity(0.07))
            .foregroundColor(isSelected ? .cream : .forestInk)
            .cornerRadius(.radiusTag)
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

            Button(photoManager.authorizationStatus == .denied ? "Open Settings" : "Grant Access") {
                if photoManager.authorizationStatus == .denied ||
                    photoManager.authorizationStatus == .restricted {
                    photoManager.openAppSettings()
                } else {
                    Task { await photoManager.requestAuthorization() }
                }
            }
            .buttonStyle(PippiPrimaryButtonStyle())
        }
        .padding()
    }
}

struct EmptyStateView: View {
    @EnvironmentObject private var photoManager: PhotoManager
    @Binding var showingScanner: Bool
    var hasSavedResults = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingPhotoPicker = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 58, weight: .semibold))
                .foregroundColor(.forestInk)
                .frame(width: 112, height: 112)
                .background(Color.mintSage.opacity(0.55))
                .clipShape(Circle())

            Text(hasSavedResults ? "Let’s Rebuild Your Library" : "Start With a Few Photos")
                .font(.pippi(25, weight: .extraBold))
                .foregroundColor(.forestInk)

            Text(hasSavedResults
                 ? "Your scan history is still safe, but some saved photo references are no longer available. Scan again to reconnect the photos currently on this device."
                 : emptyDescription)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if photoManager.isScanning {
                VStack(spacing: 8) {
                    ProgressView(value: photoManager.scanProgress)
                        .tint(.forestInk)
                    Text("Checking \(photoManager.scannedPhotosCount) of \(photoManager.totalPhotosToScan)…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 30)
            } else {
                Button {
                    showingScanner = true
                } label: {
                    Label("FIND MY PET PHOTOS", systemImage: "sparkle.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PippiPrimaryButtonStyle())
                .padding(.horizontal, 24)

                Button("Add Specific Photos Instead") {
                    Task { await openPhotoChooser() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.forestInk)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream)
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 50,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { items in
            guard !items.isEmpty else { return }
            Task {
                await photoManager.importSelectedPhotos(items: items)
                selectedPhotoItems = []
            }
        }
    }

    @MainActor
    private func openPhotoChooser() async {
        if photoManager.authorizationStatus == .notDetermined {
            await photoManager.requestAuthorization()
        }
        if photoManager.authorizationStatus == .limited {
            photoManager.chooseMoreLimitedPhotos()
        } else if photoManager.authorizationStatus == .authorized {
            showingPhotoPicker = true
        }
    }

    private var emptyDescription: String {
        if photoManager.authorizationStatus == .limited {
            return "PiPi currently has access to \(photoManager.libraryPhotoCount.formatted()) selected photo\(photoManager.libraryPhotoCount == 1 ? "" : "s"). Choose more photos to find additional pet moments."
        }
        return "Choose only the photos you’re comfortable sharing. PiPi checks them privately on this device."
    }
}

struct LibraryRestoreView: View {
    @EnvironmentObject private var photoManager: PhotoManager

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.forestInk)
            Text("Restoring Your Library")
                .font(.pippi(22, weight: .extraBold))
                .foregroundColor(.forestInk)
            Text("Reconnecting your saved pet photos…")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if photoManager.restoreTotalCount > 0 {
                ProgressView(
                    value: Double(photoManager.restoreCompletedCount),
                    total: Double(photoManager.restoreTotalCount)
                )
                .tint(.forestInk)
                .padding(.horizontal, 44)
                Text("\(photoManager.restoreCompletedCount.formatted()) of \(photoManager.restoreTotalCount.formatted()) records checked")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream)
    }
}

struct LibraryRecoveryView: View {
    @EnvironmentObject private var photoManager: PhotoManager
    let savedCount: Int

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 52, weight: .semibold))
                .foregroundColor(.forestInk)
            Text("Your Saved Library Is Still Here")
                .font(.pippi(24, weight: .extraBold))
                .foregroundColor(.forestInk)
            Text("PiPi has \(savedCount.formatted()) saved photo records, but iOS has not reconnected their images yet.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 28)
            Button("RECONNECT SAVED LIBRARY") {
                photoManager.restorePersistedLibrary()
            }
            .buttonStyle(PippiPrimaryButtonStyle())
            .padding(.horizontal, 28)
            Button("Check Photo Access in Settings") {
                photoManager.openAppSettings()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.forestInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream)
    }
}

// MARK: - Recent Photos

struct RecentPhotosView: View {
    @EnvironmentObject var photoManager: PhotoManager
    var onScrollOffset: (CGFloat) -> Void = { _ in }

    var recentPhotos: [PetPhoto] {
        photoManager.filteredPetPhotos
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: VerticalScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("libraryPhotoScroll")).minY
                    )
                }
                .frame(height: 0)

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
                            NavigationLink(destination: PhotoDetailView(photo: photo, photos: recentPhotos)) {
                                PhotoThumbnailView(photo: photo)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .coordinateSpace(name: "libraryPhotoScroll")
        .onPreferenceChange(VerticalScrollOffsetPreferenceKey.self) { offset in
            onScrollOffset(offset)
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
