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

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // Animated icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 150, height: 150)

                    Image(systemName: isScanning ? "pawprint.fill" : "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isScanning ? 360 : 0))
                        .animation(
                            isScanning ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                            value: isScanning
                        )
                }

                VStack(spacing: 12) {
                    Text(isScanning ? "Scanning Photos" : "Ready to Scan")
                        .font(.title2)
                        .fontWeight(.bold)

                    if isScanning {
                        Text("Analyzing your photo library for pet photos...")
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
                        Text("This will scan your entire photo library and identify photos containing pets.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                }

                if !isScanning {
                    Button(action: startScanning) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Scanning")
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
                        Text("\(photoManager.petPhotos.count) pet photos found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if photoManager.scanProgress >= 1.0 {
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Done")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green)
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

    private func startScanning() {
        isScanning = true
        Task {
            await photoManager.scanPhotoLibrary()
        }
    }
}

#Preview {
    ScannerView()
        .environmentObject(PhotoManager())
}
