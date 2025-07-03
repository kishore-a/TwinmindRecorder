//
//  ContentView.swift
//  TwinmindRecorder
//
//  Created by Kishore Shankar Abimanyu on 7/2/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var recorder = AudioRecorderManager()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            // Recording Tab
            VStack(spacing: 24) {
                Text("Twinmind Recorder")
                    .font(.largeTitle)
                    .bold()
                
                // Recording Controls
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        Button(action: {
                            recorder.startRecording()
                        }) {
                            Image(systemName: "record.circle")
                                .resizable()
                                .frame(width: 48, height: 48)
                                .foregroundColor(recorder.isRecording ? .red : .gray)
                        }
                        .disabled(recorder.isRecording)
                        
                        Button(action: {
                            recorder.stopRecording()
                        }) {
                            Image(systemName: "stop.circle")
                                .resizable()
                                .frame(width: 48, height: 48)
                                .foregroundColor(recorder.isRecording ? .red : .gray)
                        }
                        .disabled(!recorder.isRecording)
                    }
                    .padding()
                    
                    Text(recorder.isRecording ? "Recording..." : "Tap to record")
                        .foregroundColor(.secondary)
                    
                    // Error display
                    if let error = recorder.error {
                        Text("Error: \(error.localizedDescription)")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                            .background(Color(.systemRed).opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Permission denied message
                    if recorder.permissionDenied {
                        Text("Microphone access is required to record audio")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .padding()
                            .background(Color(.systemOrange).opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                
                // Current session info
                if recorder.isRecording {
                    VStack(spacing: 8) {
                        Text("Current Session")
                            .font(.headline)
                        Text("\(recorder.segments.count) segments recorded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBlue).opacity(0.1))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "mic")
                Text("Record")
            }
            .onAppear {
                // Set the SwiftData context for the recorder
                recorder.setModelContext(modelContext)
            }
            
            // Sessions Tab
            SessionListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Sessions")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: RecordingSession.self, inMemory: true)
}
