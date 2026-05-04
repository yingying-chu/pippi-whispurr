//
//  ContentView.swift
//  PippiWhispurr
//
//  Main view with calendar and photo display
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var selectedDate: Date?
    @State private var showingScanner = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if photoManager.authorizationStatus == .notDetermined ||
                   photoManager.authorizationStatus == .denied {
                    PermissionView()
                } else if photoManager.petPhotos.isEmpty && !photoManager.isScanning {
                    EmptyStateView(showingScanner: $showingScanner)
                } else {
                    StatsHeaderView()

                    FilterBarView()

                    CalendarView(selectedDate: $selectedDate)

                    Divider()

                    if let date = selectedDate {
                        PhotoGridView(date: date)
                    } else {
                        RecentPhotosView()
                    }
                }
            }
            .navigationTitle("PiPi 🐾")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingScanner = true }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScannerView()
            }
        }
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
                FilterChip(label: "All", emoji: nil, isSelected: photoManager.activeFilter == nil) {
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
        Array(photoManager.petPhotos
            .filter { photoManager.activeFilter == nil || $0.petType == photoManager.activeFilter }
            .prefix(20))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recent Pet Photos")
                    .font(.headline)
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

#Preview {
    ContentView()
        .environmentObject(PhotoManager())
}
