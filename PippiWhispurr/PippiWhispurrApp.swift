//
//  PippiWhispurrApp.swift
//  PippiWhispurr
//
//  A pet photo calendar app that scans your iPhone photo library
//

import SwiftUI

@main
struct PippiWhispurrApp: App {
    @StateObject private var photoManager = PhotoManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoManager)
        }
    }
}
