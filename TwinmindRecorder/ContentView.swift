//
//  ContentView.swift
//  TwinmindRecorder
//
//  Created by Kishore Shankar Abimanyu on 7/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var recorder = AudioRecorderManager()
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Twinmind Recorder")
                .font(.largeTitle)
                .bold()
            HStack(spacing: 20) {
                Button(action: {
                    recorder.startRecording()
                }) {
                    Image(systemName: "record.circle")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundColor(recorder.isRecording ? .red : .gray)
                }
                Button(action: {
                    recorder.stopRecording()
                }) {
                    Image(systemName: "stop.circle")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            Text(recorder.isRecording ? "Recording..." : "Tap to record")
                .foregroundColor(.secondary)
            Divider()
            Text("Session List (placeholder)")
                .font(.headline)
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
