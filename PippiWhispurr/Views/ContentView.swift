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
                    CalendarView(selectedDate: $selectedDate)

                    if let date = selectedDate {
                        PhotoGridView(date: date)
                    } else {
                        RecentPhotosView()
                    }
                }
            }
            .navigationTitle("Pet Calendar 🐾")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingScanner = true
                    }) {
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

            Text("PippiWhispurr needs access to your photo library to scan and identify photos of your pets.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Grant Access") {
                Task {
                    await photoManager.requestAuthorization()
                }
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

struct RecentPhotosView: View {
    @EnvironmentObject var photoManager: PhotoManager

    var recentPhotos: [PetPhoto] {
        Array(photoManager.petPhotos.prefix(20))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recent Pet Photos")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)

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

#Preview {
    ContentView()
        .environmentObject(PhotoManager())
}
