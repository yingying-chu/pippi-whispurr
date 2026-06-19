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
            ContentView()
                .environmentObject(photoManager)
                .environmentObject(storyStore)
        }
    }
}
