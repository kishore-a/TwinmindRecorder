//
//  TwinmindRecorderApp.swift
//  TwinmindRecorder
//
//  Created by Kishore Shankar Abimanyu on 7/2/25.
//

import SwiftUI
import SwiftData

@main
struct TwinmindRecorderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [RecordingSession.self, AudioSegment.self, Transcription.self])
    }
}
