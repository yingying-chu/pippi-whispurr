//
//  PippiWhispurrApp.swift
//  PippiWhispurr
//
//  A pet photo calendar app that scans your iPhone photo library
//

import SwiftUI

@main
struct PippiWhispurrApp: App {
    @StateObject private var storyStore: StoryStore
    @StateObject private var photoManager: PhotoManager

    init() {
        let storyStore = StoryStore()
        _storyStore = StateObject(wrappedValue: storyStore)
        _photoManager = StateObject(
            wrappedValue: PhotoManager(storyStore: storyStore)
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if storyStore.isLoaded {
                    ContentView()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.orange)
                        Text("PiPi")
                            .font(.largeTitle.bold())
                        ProgressView()
                    }
                }
            }
            .environmentObject(photoManager)
            .environmentObject(storyStore)
        }
    }
}
