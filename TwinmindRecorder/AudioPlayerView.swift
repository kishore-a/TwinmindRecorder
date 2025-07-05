import SwiftUI

struct AudioPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    let session: RecordingSession
    
    @State private var isSessionLoaded = false
    @State private var showingSegmentPicker = false
    
    var body: some View {
        ModernCard(shadow: DesignSystem.Shadows.medium) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Session info header
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Audio Player")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text("Session: \(session.date, style: .date)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        
                        // Playback status indicator
                        if audioPlayer.isPlaying {
                            StatusBadge(
                                text: "Playing",
                                color: DesignSystem.Colors.success,
                                icon: "play.circle.fill"
                            )
                        }
                    }
                }
                
                // Load session button
                if !isSessionLoaded {
                    GradientButton(
                        gradient: DesignSystem.Colors.primaryGradient,
                        action: { loadSession() }
                    ) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                            Text("Load Session Audio")
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                } else {
                    // Audio controls
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Progress info
                        if let segmentInfo = audioPlayer.getCurrentSegmentInfo() {
                            HStack {
                                StatusBadge(
                                    text: "Segment \(segmentInfo.index + 1)",
                                    color: DesignSystem.Colors.primary,
                                    icon: "waveform"
                                )
                                Spacer()
                                Text("\(segmentInfo.time) / \(segmentInfo.duration)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .monospacedDigit()
                            }
                        }
                        
                        // Progress bar
                        if audioPlayer.duration > 0 {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                ProgressView(value: audioPlayer.currentTime, total: audioPlayer.duration)
                                    .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.primary))
                                    .scaleEffect(y: 1.5)
                                    .onTapGesture { location in
                                        // Handle tap to seek (simplified)
                                        let percentage = location.x / UIScreen.main.bounds.width
                                        let seekTime = audioPlayer.duration * percentage
                                        audioPlayer.seek(to: seekTime)
                                    }
                                
                                HStack {
                                    Text(audioPlayer.formattedTime(audioPlayer.currentTime))
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .monospacedDigit()
                                    Spacer()
                                    Text(audioPlayer.formattedTime(audioPlayer.duration))
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        
                        // Main controls
                        HStack(spacing: DesignSystem.Spacing.xl) {
                            // Previous segment
                            IconButton(
                                icon: "backward.fill",
                                color: DesignSystem.Colors.primary,
                                size: 24,
                                isEnabled: audioPlayer.hasSegment(audioPlayer.currentSegment - 1)
                            ) {
                                audioPlayer.playPreviousSegment()
                            }
                            
                            // Play/Pause
                            Button(action: {
                                if audioPlayer.isPlaying {
                                    audioPlayer.pause()
                                } else {
                                    audioPlayer.play()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(audioPlayer.isPlaying ? DesignSystem.Colors.recordingGradient : DesignSystem.Colors.primaryGradient)
                                        .frame(width: 70, height: 70)
                                        .shadow(color: (audioPlayer.isPlaying ? DesignSystem.Colors.recording : DesignSystem.Colors.primary).opacity(0.3), radius: 10, x: 0, y: 5)
                                    
                                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 30, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .scaleEffect(audioPlayer.isPlaying ? 1.05 : 1.0)
                            .animation(Animations.spring, value: audioPlayer.isPlaying)
                            
                            // Next segment
                            IconButton(
                                icon: "forward.fill",
                                color: DesignSystem.Colors.primary,
                                size: 24,
                                isEnabled: audioPlayer.hasSegment(audioPlayer.currentSegment + 1)
                            ) {
                                audioPlayer.playNextSegment()
                            }
                        }
                        
                        // Secondary controls
                        HStack(spacing: DesignSystem.Spacing.md) {
                            // Stop button
                            GradientButton(
                                gradient: LinearGradient(colors: [DesignSystem.Colors.error, DesignSystem.Colors.error.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                                isEnabled: audioPlayer.isPlaying,
                                action: {
                                    audioPlayer.stop()
                                }
                            ) {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "stop.fill")
                                        .font(.caption)
                                    Text("Stop")
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            // Segment picker
                            GradientButton(
                                gradient: DesignSystem.Colors.secondaryGradient,
                                isEnabled: true,
                                action: {
                                    showingSegmentPicker = true
                                }
                            ) {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "list.bullet")
                                        .font(.caption)
                                    Text("Select Segment")
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }
                
                // Error display
                if let error = audioPlayer.error {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DesignSystem.Colors.error)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Playback Error")
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(.medium)
                            Text(error)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.error.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .sheet(isPresented: $showingSegmentPicker) {
            SegmentPickerView(audioPlayer: audioPlayer)
        }
    }
    
    private func loadSession() {
        audioPlayer.loadSessionFromRecordingSession(session) { success in
            isSessionLoaded = success
            if success {
                audioPlayer.playSession()
            }
        }
    }
}

struct SegmentPickerView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(audioPlayer.getSegmentIndices(), id: \.self) { segmentIndex in
                        ModernCard(shadow: DesignSystem.Shadows.small) {
                            Button(action: {
                                audioPlayer.seekToSegment(segmentIndex)
                                dismiss()
                            }) {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    // Segment number
                                    ZStack {
                                        Circle()
                                            .fill(DesignSystem.Colors.primaryGradient)
                                            .frame(width: 40, height: 40)
                                        
                                        Text("\(segmentIndex + 1)")
                                            .font(DesignSystem.Typography.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    
                                    // Segment info
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                        Text("Segment \(segmentIndex + 1)")
                                            .font(DesignSystem.Typography.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(DesignSystem.Colors.textPrimary)
                                        Text("Duration: \(audioPlayer.formattedTime(audioPlayer.getSegmentDuration(segmentIndex)))")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Current segment indicator
                                    if segmentIndex == audioPlayer.currentSegment {
                                        Image(systemName: "play.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(DesignSystem.Colors.primary)
                                    }
                                }
                                .padding(DesignSystem.Spacing.md)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.secondaryBackground)
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
        HStack(spacing: DesignSystem.Spacing.md) {
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
                ZStack {
                    Circle()
                        .fill(audioPlayer.isPlaying ? DesignSystem.Colors.recordingGradient : DesignSystem.Colors.primaryGradient)
                        .frame(width: 36, height: 36)
                        .shadow(color: (audioPlayer.isPlaying ? DesignSystem.Colors.recording : DesignSystem.Colors.primary).opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(audioPlayer.isPlaying ? 1.1 : 1.0)
            .animation(Animations.spring, value: audioPlayer.isPlaying)
            
            // Session info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Quick Play")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text(audioPlayer.isPlaying ? "Playing..." : "Tap to play")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Progress indicator
            if audioPlayer.isPlaying && audioPlayer.duration > 0 {
                ProgressRing(
                    progress: audioPlayer.currentTime / audioPlayer.duration,
                    color: DesignSystem.Colors.primary,
                    size: 24,
                    lineWidth: 2
                )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.tertiaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
    
    private func loadSession() {
        audioPlayer.loadSessionFromRecordingSession(session) { success in
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