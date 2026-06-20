//
//  ScannerView.swift
//  PippiWhispurr
//
//  Shows scanning progress when analyzing photo library
//

import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @Environment(\.dismiss) var dismiss

    private var activelyScanning: Bool {
        photoManager.isScanning && photoManager.scanProgress < 1.0
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // Animated icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 150, height: 150)

                    Image(systemName: activelyScanning ? "pawprint.fill" : "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(activelyScanning ? 360 : 0))
                        .animation(
                            activelyScanning ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                            value: activelyScanning
                        )
                }

                VStack(spacing: 12) {
                    Text(activelyScanning ? "Finding Pet Moments" : scanTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    if activelyScanning {
                        Text("\(photoManager.scannedPhotosCount) of \(photoManager.totalPhotosToScan) checked")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        ProgressView(value: photoManager.scanProgress)
                            .progressViewStyle(.linear)
                            .padding(.horizontal, 40)
                            .padding(.top, 8)

                        Text("\(Int(photoManager.scanProgress * 100))%")
                            .font(.headline)
                            .foregroundColor(.blue)

                        if let seconds = photoManager.estimatedSecondsRemaining,
                           seconds > 1 {
                            Text("About \(durationText(seconds)) remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(scanDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)

                        Text("\(photoManager.libraryPhotoCount.formatted()) photos · \(photoManager.remainingPhotoCount.formatted()) left to check")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let seconds = photoManager.estimatedTotalSeconds,
                           photoManager.remainingPhotoCount > 0 {
                            Text("Estimated time: about \(durationText(seconds))")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.blue)
                        }
                    }
                }

                if !photoManager.isScanning && photoManager.remainingPhotoCount > 0 {
                    Button(action: startScanning) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Scan All Remaining")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    }
                } else if photoManager.isScanning {
                    VStack(spacing: 16) {
                        Text("You can keep using PiPi while this continues.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button {
                            dismiss()
                        } label: {
                            Label("Scan in Background", systemImage: "arrow.down.right.and.arrow.up.left")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                                .padding(.horizontal, 40)
                        }

                        Text("Progress is saved automatically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !photoManager.isScanning && photoManager.remainingPhotoCount == 0 && photoManager.scanProgress >= 1.0 {
                    VStack(spacing: 14) {
                        Text(completionSummary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("Done") {
                            dismiss()
                        }
                            .font(.headline)
                            .padding(.vertical, 8)
                    }
                }

                Spacer()
            }
            .navigationTitle("Pet Scanner")
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
        }
    }

    private var scanTitle: String {
        if !photoManager.isScanning && photoManager.remainingPhotoCount == 0 {
            return "You're All Caught Up"
        }
        if !photoManager.isScanning && photoManager.scanProgress >= 1.0 {
            return "Batch Complete"
        }
        return "Ready to Scan"
    }

    private var scanDescription: String {
        if !photoManager.isScanning && photoManager.remainingPhotoCount == 0 {
            return "PiPi has analyzed all currently available photos. New photos can be scanned later."
        }
        if !photoManager.isScanning && photoManager.scanProgress >= 1.0 {
            return "This batch is safely saved. You can continue with another batch now or return later."
        }
        return "PiPi can check everything that remains. You can keep using the app while it finds pet photos and understands what is happening in them."
    }

    private var completionSummary: String {
        if photoManager.lastBatchHadNoPhotos {
            return "No unscanned photos remain"
        }
        return "\(photoManager.petPhotos.count) pet photos found in total"
    }

    private func startScanning() {
        Task {
            await photoManager.scanAllRemainingPhotos()
        }
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
