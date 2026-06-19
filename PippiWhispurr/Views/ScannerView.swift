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
    @State private var isScanning = false

    private let batchSizes = [1000, 2000, 3000]

    private var activelyScanning: Bool {
        isScanning && photoManager.scanProgress < 1.0
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
                        .rotationEffect(.degrees(isScanning ? 360 : 0))
                        .animation(
                            activelyScanning ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                            value: activelyScanning
                        )
                }

                VStack(spacing: 12) {
                    Text(activelyScanning ? "Scanning Photos" : scanTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    if activelyScanning {
                        Text("Scanning \(photoManager.scannedPhotosCount) of \(photoManager.totalPhotosToScan) photos...")
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
                    } else {
                        Text(scanDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)

                        if !isScanning {
                            Picker("Photos this batch", selection: $photoManager.scanBatchSize) {
                                ForEach(batchSizes, id: \.self) { size in
                                    Text(size.formatted()).tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 30)

                            Text("\(photoManager.analyzedPhotosCount.formatted()) photos analyzed so far")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if !isScanning {
                    Button(action: startScanning) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(photoManager.analyzedPhotosCount == 0 ? "Start Scanning" : "Scan More Photos")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text(completionSummary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if photoManager.scanProgress >= 1.0 {
                            if !photoManager.lastBatchHadNoPhotos {
                                Button(action: startScanning) {
                                    Text("Scan Next \(photoManager.scanBatchSize.formatted())")
                                        .font(.headline)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .padding(.horizontal, 40)
                                }
                            }

                            Button("Done") {
                                dismiss()
                            }
                            .font(.headline)
                            .padding(.vertical, 8)
                        } else {
                            Button(action: {
                                photoManager.cancelScan()
                                isScanning = false
                            }) {
                                Text("Cancel Scan")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 40)
                            }
                        }
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
                    .disabled(isScanning && photoManager.scanProgress < 1.0)
                }
            }
        }
    }

    private var scanTitle: String {
        if isScanning && photoManager.lastBatchHadNoPhotos {
            return "You're All Caught Up"
        }
        if isScanning && photoManager.scanProgress >= 1.0 {
            return "Batch Complete"
        }
        return "Ready to Scan"
    }

    private var scanDescription: String {
        if isScanning && photoManager.lastBatchHadNoPhotos {
            return "PiPi has analyzed all currently available photos. New photos can be scanned later."
        }
        if isScanning {
            return "This batch is safely saved. You can continue with another batch now or return later."
        }
        return "Start with a manageable batch. PiPi remembers every analyzed photo, so future scans continue without starting over."
    }

    private var completionSummary: String {
        if photoManager.lastBatchHadNoPhotos {
            return "No unscanned photos remain"
        }
        return "\(photoManager.petPhotos.count) pet photos found in total"
    }

    private func startScanning() {
        isScanning = true
        Task {
            await photoManager.scanPhotoLibrary()
        }
    }
}

struct ScannerView_Previews: PreviewProvider {
    static var previews: some View {
        ScannerView()
            .environmentObject(PhotoManager())
    }
}
