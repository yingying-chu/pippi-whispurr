//
//  ScannerView.swift
//  PippiWhispurr
//
//  Shows scanning progress when analyzing photo library
//

import SwiftUI
import PhotosUI

struct ScannerView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingPhotoPicker = false
    @State private var showingPermissionAlert = false
    @State private var scanNotice: String?
    @State private var showingRebuildConfirmation = false

    private var activelyScanning: Bool {
        photoManager.isScanning && photoManager.scanProgress < 1.0
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 22) {
                    scannerIcon

                    if photoManager.isScanning {
                        scanningContent
                    } else {
                        choiceContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 36)
            }
            .background(Color.cream.ignoresSafeArea())
            .navigationTitle("Find Pet Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await photoManager.prepareScanSummary()
            }
            .onAppear {
                photoManager.setScannerPresented(true)
            }
            .onDisappear {
                photoManager.setScannerPresented(false)
            }
            .onChange(of: selectedPhotoItems) { items in
                guard !items.isEmpty else { return }
                Task {
                    let importedCount = await photoManager.importSelectedPhotos(items: items)
                    selectedPhotoItems = []
                    scanNotice = importedCount > 0
                        ? "Added \(importedCount) specific photo\(importedCount == 1 ? "" : "s") to Library"
                        : "PiPi couldn’t read the selected photos. Please try again."
                }
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $selectedPhotoItems,
                maxSelectionCount: 50,
                matching: .images
            )
            .alert("Photo Access Needed", isPresented: $showingPermissionAlert) {
                Button("Not Now", role: .cancel) {}
                Button("Open Settings") {
                    photoManager.openAppSettings()
                }
            } message: {
                Text("Allow PiPi to access your photos so it can find pet moments. You can choose Limited Access or Full Access.")
            }
            .confirmationDialog(
                "Rebuild the entire Library?",
                isPresented: $showingRebuildConfirmation,
                titleVisibility: .visible
            ) {
                Button("Recheck All Accessible Photos") {
                    Task { await startRebuildScan() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("PiPi will recheck photos that scan history marked as reviewed. This can take a while for a large library, but it will not create duplicate entries.")
            }
        }
    }

    private var scannerIcon: some View {
        ZStack {
            Circle()
                .fill(Color.mintSage.opacity(0.55))
                .frame(width: 104, height: 104)
            Image(systemName: activelyScanning ? "pawprint.fill" : "photo.badge.magnifyingglass")
                .font(.system(size: 42, weight: .semibold))
                .foregroundColor(.forestInk)
                .rotationEffect(.degrees(activelyScanning ? 360 : 0))
                .animation(
                    activelyScanning ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                    value: activelyScanning
                )
        }
    }

    private var choiceContent: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Where would you like to start?")
                    .font(.pippi(25, weight: .extraBold))
                    .foregroundColor(.forestInk)
                    .multilineTextAlignment(.center)
                Text("Start small, or let PiPi look for older moments when you’re ready.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            privacyCard

            if photoManager.authorizationStatus == .limited {
                limitedAccessCard
            }

            if let scanNotice {
                Label(scanNotice, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.forestInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.mintSage.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: .radiusCard, style: .continuous))
            }

            Button {
                Task { await startRecentScan() }
            } label: {
                scanChoice(
                    icon: "clock.arrow.circlepath",
                    title: "Start with Recent Photos",
                    detail: "PiPi checks the last 30 days for you",
                    highlighted: true
                )
            }
            .buttonStyle(.plain)

            Button {
                Task { await startFullScan() }
            } label: {
                scanChoice(
                    icon: "sparkle.magnifyingglass",
                    title: "Find New Pet Photos",
                    detail: allPhotosDetail,
                    highlighted: false
                )
            }
            .buttonStyle(.plain)

            Button {
                showingRebuildConfirmation = true
            } label: {
                scanChoice(
                    icon: "arrow.clockwise.circle",
                    title: photoManager.petPhotos.isEmpty && photoManager.analyzedPhotosCount > 0
                        ? "Rebuild Empty Library"
                        : "Recheck Entire Library",
                    detail: "Recheck all \(photoManager.libraryPhotoCount.formatted()) accessible photos",
                    highlighted: false
                )
            }
            .buttonStyle(.plain)

            Button {
                Task { await openPhotoChooser() }
            } label: {
                scanChoice(
                    icon: "photo.badge.plus",
                    title: "Add Specific Photos",
                    detail: "For a few photos you already have in mind",
                    highlighted: false
                )
            }
            .buttonStyle(.plain)

            if photoManager.scanProgress >= 1 {
                Text(completionSummary)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.forestInk.opacity(0.7))
            }
        }
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundColor(.forestInk)
            VStack(alignment: .leading, spacing: 4) {
                Text("Private by design")
                    .font(.pippi(15, weight: .semibold))
                    .foregroundColor(.forestInk)
                Text("Photos are checked on this device. Nothing is uploaded. Already checked photos are skipped automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: .radiusCard, style: .continuous))
    }

    @MainActor
    private func startRecentScan() async {
        scanNotice = nil
        await photoManager.scanRecentPhotos()
        if !showPermissionHelpIfNeeded() {
            if photoManager.totalPhotosToScan == 0 {
                scanNotice = photoManager.libraryPhotoCount == 0
                    ? "PiPi cannot currently access any photos"
                    : "No accessible photos were taken in the last 30 days"
            } else {
                scanNotice = "Checked \(photoManager.scannedPhotosCount) recent photos — \(photoManager.petPhotos.count) pet photos found"
            }
        }
    }

    @MainActor
    private func startFullScan() async {
        scanNotice = nil
        await photoManager.scanAllRemainingPhotos()
        if !showPermissionHelpIfNeeded() {
            scanNotice = photoManager.lastBatchHadNoPhotos
                ? "Your accessible photo library is already up to date"
                : "Library checked — \(photoManager.petPhotos.count) pet photos found so far"
        }
    }

    @MainActor
    private func startRebuildScan() async {
        scanNotice = nil
        await photoManager.rescanEntireLibrary()
        if !showPermissionHelpIfNeeded() {
            scanNotice = "Library rebuilt — \(photoManager.petPhotos.count) pet photos found"
        }
    }

    @MainActor
    private func showPermissionHelpIfNeeded() -> Bool {
        if photoManager.authorizationStatus == .denied ||
            photoManager.authorizationStatus == .restricted {
            showingPermissionAlert = true
            return true
        }
        return false
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

    private var limitedAccessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Limited Photo Access", systemImage: "exclamationmark.triangle.fill")
                .font(.pippi(15, weight: .semibold))
                .foregroundColor(.forestInk)
            Text("PiPi can currently see only \(photoManager.libraryPhotoCount.formatted()) selected photo\(photoManager.libraryPhotoCount == 1 ? "" : "s"). Other photos cannot be checked yet.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Choose More Photos") {
                photoManager.chooseMoreLimitedPhotos()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.forestInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.honeyYellow.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: .radiusCard, style: .continuous))
    }

    private func scanChoice(
        icon: String,
        title: String,
        detail: String,
        highlighted: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 42, height: 42)
                .background(highlighted ? Color.honeyYellow : Color.forestInk.opacity(0.08))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.pippi(16, weight: .semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(highlighted ? .cream.opacity(0.75) : .secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
        }
        .foregroundColor(highlighted ? .cream : .forestInk)
        .padding(16)
        .background(highlighted ? Color.forestInk : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: .radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusCard, style: .continuous)
                .stroke(Color.forestInk.opacity(0.08), lineWidth: 1)
        )
    }

    private var allPhotosDetail: String {
        if photoManager.authorizationStatus == .limited {
            return "Check \(photoManager.remainingPhotoCount.formatted()) newly accessible photos; only selected photos are visible"
        }
        guard photoManager.libraryPhotoCount > 0 else {
            return "You’ll choose photo access before anything starts"
        }
        return "Check \(photoManager.remainingPhotoCount.formatted()) new photos; previously reviewed photos are skipped"
    }

    private var scanningContent: some View {
        VStack(spacing: 16) {
            Text("Finding Pet Moments")
                .font(.pippi(25, weight: .extraBold))
                .foregroundColor(.forestInk)
            Text("\(photoManager.scannedPhotosCount) of \(photoManager.totalPhotosToScan) checked")
                .foregroundColor(.secondary)
            ProgressView(value: photoManager.scanProgress)
                .tint(.forestInk)
            Text("\(Int(photoManager.scanProgress * 100))%")
                .font(.pippi(18, weight: .semibold))
                .foregroundColor(.forestInk)

            Button {
                dismiss()
            } label: {
                Label("Keep Using PiPi", systemImage: "arrow.down.right.and.arrow.up.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PippiPrimaryButtonStyle())

            Button {
                photoManager.pauseScan()
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
            .buttonStyle(.bordered)
        }
    }

    private var completionSummary: String {
        if photoManager.lastBatchHadNoPhotos {
            return "No new photos to check here — this selection is already up to date"
        }
        if photoManager.authorizationStatus == .limited && photoManager.petPhotos.isEmpty {
            return "No pet photos found in the limited selection"
        }
        return "\(photoManager.petPhotos.count) pet photos found so far"
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "less than a minute"
        }
        let minutes = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0 ? "\(hours) hr" : "\(hours) hr \(remainingMinutes) min"
    }
}

struct ScannerView_Previews: PreviewProvider {
    static var previews: some View {
        ScannerView()
            .environmentObject(PhotoManager())
    }
}
