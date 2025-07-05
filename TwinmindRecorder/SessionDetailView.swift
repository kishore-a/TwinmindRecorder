import SwiftUI
import SwiftData

// MARK: - Supporting Views

struct TranscriptionStatusView: View {
    let transcription: Transcription?
    
    var body: some View {
        switch transcription?.status {
        case .completed:
            StatusBadge(
                text: "Completed",
                color: DesignSystem.Colors.success,
                icon: "checkmark.circle.fill"
            )
        case .processing:
            StatusBadge(
                text: "Processing",
                color: DesignSystem.Colors.warning,
                icon: "clock.fill"
            )
        case .failed:
            StatusBadge(
                text: "Failed",
                color: DesignSystem.Colors.error,
                icon: "exclamationmark.circle.fill"
            )
        case .pending, nil:
            StatusBadge(
                text: "Pending",
                color: DesignSystem.Colors.textTertiary,
                icon: "circle"
            )
        }
    }
}

struct TranscriptionContentView: View {
    let transcription: Transcription?
    @Environment(\.modelContext) private var modelContext
    @State private var isRetrying = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if let transcription = transcription {
                switch transcription.status {
                case .completed:
                    if !transcription.text.isEmpty {
                        ModernCard(shadow: DesignSystem.Shadows.small) {
                            Text(transcription.text)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .padding(DesignSystem.Spacing.md)
                        }
                    } else {
                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                            Text("No transcription text available")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .italic()
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.tertiaryBackground)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                case .processing:
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Transcribing...")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.tertiaryBackground)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                case .failed:
                    ModernCard(shadow: DesignSystem.Shadows.small) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(DesignSystem.Colors.error)
                                Text("Transcription Failed")
                                    .font(DesignSystem.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.error)
                            }
                            if let error = transcription.error {
                                Text(error)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
                            // Retry button
                            if let segment = transcription.segment {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        retryTranscription(for: segment)
                                    }) {
                                        HStack(spacing: DesignSystem.Spacing.xs) {
                                            if isRetrying {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                            }
                                            Text(isRetrying ? "Retrying..." : "Retry")
                                                .font(DesignSystem.Typography.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .padding(.horizontal, DesignSystem.Spacing.md)
                                        .padding(.vertical, DesignSystem.Spacing.xs)
                                        .background(DesignSystem.Colors.primary.opacity(0.1))
                                        .cornerRadius(DesignSystem.CornerRadius.sm)
                                    }
                                    .disabled(isRetrying)
                                }
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                    }
                case .pending:
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        Text("Waiting to transcribe...")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .italic()
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.tertiaryBackground)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            } else {
                HStack {
                    Image(systemName: "text.bubble.slash")
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text("No transcription available")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .italic()
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.tertiaryBackground)
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
        }
    }
    
    private func retryTranscription(for segment: AudioSegment) {
        isRetrying = true
        
        TranscriptionService.shared.retryTranscription(for: segment, context: modelContext) { _ in
            DispatchQueue.main.async {
                isRetrying = false
            }
        }
    }
}

struct SegmentRowView: View {
    let segment: AudioSegment
    @State private var isExpanded = false
    
    var body: some View {
        ModernCard(shadow: DesignSystem.Shadows.small) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Segment header
                HStack {
                    // Segment number and time
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Segment \(formatStartTime(segment.startTime))")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text(formatDuration(segment.duration))
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Transcription status
                    TranscriptionStatusView(transcription: segment.transcription)
                    
                    // Expand/collapse button
                    IconButton(
                        icon: isExpanded ? "chevron.up" : "chevron.down",
                        color: DesignSystem.Colors.primary,
                        size: 16
                    ) {
                        withAnimation(Animations.easeInOut) {
                            isExpanded.toggle()
                        }
                    }
                }
                
                // Transcription content (expandable)
                if isExpanded {
                    TranscriptionContentView(transcription: segment.transcription)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
    }
    
    private func formatStartTime(_ startTime: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: startTime)
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Main View

struct SessionDetailView: View {
    let session: RecordingSession
    @Environment(\.modelContext) private var modelContext
    @State private var displayedSegments: [AudioSegment] = []
    @State private var currentSegmentPage = 0
    @State private var isLoadingMoreSegments = false
    
    private let segmentsPerPage = 20
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.lg) {
                // Session header
                ModernCard(shadow: DesignSystem.Shadows.medium) {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        HStack {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Session Details")
                                    .font(DesignSystem.Typography.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(session.date, style: .date)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                                Text(formatDuration(session.duration))
                                    .font(DesignSystem.Typography.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.primary)
                                Text("Total Duration")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                        
                        // Transcription summary
                        TranscriptionSummaryView(session: session)
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                // Audio Player
                if !session.segments.isEmpty {
                    ModernCard(shadow: DesignSystem.Shadows.medium) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Audio Playback")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            AudioPlayerView(session: session)
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                // Segments
                ModernCard(shadow: DesignSystem.Shadows.medium) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        HStack {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Audio Segments")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text("\(displayedSegments.count)/\(session.segments.count) segments loaded")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            
                            // Segment count badge
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.primaryGradient)
                                    .frame(width: 40, height: 40)
                                
                                Text("\(session.segments.count)")
                                    .font(DesignSystem.Typography.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        if session.segments.isEmpty {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 50))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                
                                VStack(spacing: DesignSystem.Spacing.sm) {
                                    Text("No Segments")
                                        .font(DesignSystem.Typography.title3)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                    Text("No audio segments found for this session")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(DesignSystem.Spacing.xl)
                        } else {
                            LazyVStack(spacing: DesignSystem.Spacing.md) {
                                ForEach(displayedSegments) { segment in
                                    SegmentRowView(segment: segment)
                                }
                                
                                // Load more button
                                if displayedSegments.count < session.segments.count {
                                    GradientButton(
                                        gradient: DesignSystem.Colors.primaryGradient,
                                        isEnabled: !isLoadingMoreSegments,
                                        action: {
                                            loadMoreSegments()
                                        }
                                    ) {
                                        HStack(spacing: DesignSystem.Spacing.sm) {
                                            if isLoadingMoreSegments {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .foregroundColor(.white)
                                            }
                                            Text("Load More Segments")
                                                .font(DesignSystem.Typography.subheadline)
                                                .fontWeight(.medium)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.secondaryBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshSessionData()
        }
        .onAppear {
            loadInitialSegments()
        }
    }
    
    private func loadInitialSegments() {
        let sortedSegments = session.segments.sorted(by: { $0.startTime < $1.startTime })
        let initialCount = min(segmentsPerPage, sortedSegments.count)
        displayedSegments = Array(sortedSegments.prefix(initialCount))
        currentSegmentPage = 0
    }
    
    private func loadMoreSegments() {
        guard !isLoadingMoreSegments else { return }
        
        isLoadingMoreSegments = true
        currentSegmentPage += 1
        
        let sortedSegments = session.segments.sorted(by: { $0.startTime < $1.startTime })
        let nextBatchStart = currentSegmentPage * segmentsPerPage
        let nextBatchEnd = min(nextBatchStart + segmentsPerPage, sortedSegments.count)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newSegments = Array(sortedSegments[nextBatchStart..<nextBatchEnd])
            displayedSegments.append(contentsOf: newSegments)
            isLoadingMoreSegments = false
        }
    }
    
    private func refreshSessionData() async {
        // Add a small delay to show refresh indicator
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Reload segments with fresh data
        DispatchQueue.main.async {
            self.loadInitialSegments()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct TranscriptionServiceIndicator: View {
    @State private var currentMode: String = "Remote (OpenAI Whisper)"
    @State private var failureCount: Int = 0
    @State private var isFallback: Bool = false
    @State private var timer: Timer?
    @State private var showingModeSelector = false
    
    var body: some View {
        Button(action: {
            showingModeSelector = true
        }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                StatusBadge(
                    text: currentMode,
                    color: currentMode.contains("Local") ? DesignSystem.Colors.warning : DesignSystem.Colors.primary,
                    icon: currentMode.contains("Local") ? "cpu" : "cloud"
                )
                
                if isFallback {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DesignSystem.Colors.warning)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            updateTranscriptionStatus()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .alert("Transcription Mode", isPresented: $showingModeSelector) {
            Button("Remote (OpenAI Whisper)") {
                TranscriptionService.shared.switchToRemoteTranscription()
                updateTranscriptionStatus()
            }
            Button("Local (Apple Speech)") {
                TranscriptionService.shared.switchToLocalTranscription()
                updateTranscriptionStatus()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose transcription service. Local transcription works offline but may be less accurate.")
        }
    }
    
    private func updateTranscriptionStatus() {
        let status = TranscriptionService.shared.getTranscriptionStatus()
        currentMode = status.mode
        failureCount = status.failureCount
        isFallback = status.isFallback
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            updateTranscriptionStatus()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct TranscriptionStatView: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                if total > 0 {
                    Text("\(Int((Double(count) / Double(total)) * 100))%")
                        .font(DesignSystem.Typography.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct TranscriptionSummaryView: View {
    let session: RecordingSession
    
    var body: some View {
        let totalSegments = session.segments.count
        let completedTranscriptions = session.segments.filter { $0.transcription?.status == .completed }.count
        let failedTranscriptions = session.segments.filter { $0.transcription?.status == .failed }.count
        let processingTranscriptions = session.segments.filter { $0.transcription?.status == .processing }.count
        
        VStack(spacing: DesignSystem.Spacing.lg) {
            HStack {
                Text("Transcription Summary")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                // Transcription service indicator
                TranscriptionServiceIndicator()
            }
            
            HStack(spacing: DesignSystem.Spacing.md) {
                TranscriptionStatView(
                    title: "Completed",
                    count: completedTranscriptions,
                    total: totalSegments,
                    color: DesignSystem.Colors.success,
                    icon: "checkmark.circle.fill"
                )
                
                TranscriptionStatView(
                    title: "Processing",
                    count: processingTranscriptions,
                    total: totalSegments,
                    color: DesignSystem.Colors.warning,
                    icon: "clock.fill"
                )
                
                TranscriptionStatView(
                    title: "Failed",
                    count: failedTranscriptions,
                    total: totalSegments,
                    color: DesignSystem.Colors.error,
                    icon: "exclamationmark.circle.fill"
                )
            }
        }
    }
}

#Preview {
    NavigationView {
        SessionDetailView(session: RecordingSession())
    }
    .modelContainer(for: RecordingSession.self, inMemory: true)
} 