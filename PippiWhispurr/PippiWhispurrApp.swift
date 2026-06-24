//
//  PippiWhispurrApp.swift
//  PippiWhispurr
//
//  A pet photo calendar app that scans your iPhone photo library
//

import SwiftUI
import BackgroundTasks

@main
struct PippiWhispurrApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var storyStore: StoryStore
    @StateObject private var photoManager: PhotoManager

    init() {
        let storyStore = StoryStore()
        _storyStore = StateObject(wrappedValue: storyStore)
        let photoManager = PhotoManager(storyStore: storyStore)
        _photoManager = StateObject(wrappedValue: photoManager)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: PhotoManager.backgroundScanTaskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await photoManager.handleBackgroundProcessingTask(processingTask)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if storyStore.isLoaded {
                    ContentView()
                        .tint(.forestInk)
                        .accentColor(.forestInk)
                        .onAppear {
                            let appearance = UITabBarAppearance.pippiAppearance()
                            UITabBar.appearance().standardAppearance = appearance
                            UITabBar.appearance().scrollEdgeAppearance = appearance
                        }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.forestInk)
                        Text("PiPi")
                            .font(.pippi(30, weight: .extraBold))
                        ProgressView()
                    }
                }
            }
            .environmentObject(photoManager)
            .environmentObject(storyStore)
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .background:
                    photoManager.applicationDidEnterBackground()
                case .active:
                    photoManager.applicationDidBecomeActive()
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}
