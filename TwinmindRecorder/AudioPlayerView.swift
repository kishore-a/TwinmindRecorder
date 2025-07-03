import SwiftUI

struct AudioPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    let session: RecordingSession
    
    @State private var isSessionLoaded = false
    @State private var showingSegmentPicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Session info
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Player")
                    .font(.headline)
                Text("Session: \(session.date, style: .date)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Load session button
            if !isSessionLoaded {
                Button("Load Session Audio") {
                    loadSession()
                }
                .buttonStyle(.borderedProminent)
            } else {
                // Audio controls
                VStack(spacing: 12) {
                    // Progress info
                    if let segmentInfo = audioPlayer.getCurrentSegmentInfo() {
                        HStack {
                            Text("Segment \(segmentInfo.index)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(segmentInfo.time) / \(segmentInfo.duration)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Progress bar
                    if audioPlayer.duration > 0 {
                        ProgressView(value: audioPlayer.currentTime, total: audioPlayer.duration)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .onTapGesture { location in
                                // Handle tap to seek (simplified)
                                let percentage = location.x / UIScreen.main.bounds.width
                                let seekTime = audioPlayer.duration * percentage
                                audioPlayer.seek(to: seekTime)
                            }
                    }
                    
                    // Main controls
                    HStack(spacing: 20) {
                        // Previous segment
                        Button(action: {
                            audioPlayer.playPreviousSegment()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                        }
                        .disabled(!audioPlayer.hasSegment(audioPlayer.currentSegment - 1))
                        
                        // Play/Pause
                        Button(action: {
                            if audioPlayer.isPlaying {
                                audioPlayer.pause()
                            } else {
                                audioPlayer.play()
                            }
                        }) {
                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                        
                        // Next segment
                        Button(action: {
                            audioPlayer.playNextSegment()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                        .disabled(!audioPlayer.hasSegment(audioPlayer.currentSegment + 1))
                    }
                    
                    // Stop button
                    Button("Stop") {
                        audioPlayer.stop()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!audioPlayer.isPlaying)
                    
                    // Segment picker
                    Button("Select Segment") {
                        showingSegmentPicker = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Error display
            if let error = audioPlayer.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color(.systemRed).opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingSegmentPicker) {
            SegmentPickerView(audioPlayer: audioPlayer)
        }
    }
    
    private func loadSession() {
        audioPlayer.loadSession(session.id) { success in
            isSessionLoaded = success
        }
    }
}

struct SegmentPickerView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(audioPlayer.getSegmentIndices(), id: \.self) { segmentIndex in
                    Button(action: {
                        audioPlayer.seekToSegment(segmentIndex)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Segment \(segmentIndex)")
                                    .font(.headline)
                                Text("Duration: \(audioPlayer.formattedTime(audioPlayer.getSegmentDuration(segmentIndex)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if segmentIndex == audioPlayer.currentSegment {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Select Segment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Compact audio player for session list
struct CompactAudioPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    let session: RecordingSession
    
    @State private var isSessionLoaded = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button(action: {
                if !isSessionLoaded {
                    loadSession()
                } else if audioPlayer.isPlaying {
                    audioPlayer.pause()
                } else {
                    audioPlayer.play()
                }
            }) {
                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // Session info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(session.segments.count) segments")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if audioPlayer.isPlaying {
                    Text("Playing segment \(audioPlayer.currentSegment)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Stop button
            if audioPlayer.isPlaying {
                Button(action: {
                    audioPlayer.stop()
                }) {
                    Image(systemName: "stop.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func loadSession() {
        audioPlayer.loadSession(session.id) { success in
            isSessionLoaded = success
            if success {
                audioPlayer.playSession()
            }
        }
    }
}

#Preview {
    AudioPlayerView(session: RecordingSession())
} 