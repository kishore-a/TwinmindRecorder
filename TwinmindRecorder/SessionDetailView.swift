import SwiftUI
import SwiftData

struct SessionDetailView: View {
    let session: RecordingSession
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Session header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Session Details")
                                .font(.title2)
                                .bold()
                            Text(session.date, style: .date)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(formatDuration(session.duration))
                                .font(.title3)
                                .bold()
                            Text("Total Duration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Transcription summary
                    TranscriptionSummaryView(session: session)
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Audio Player
                if !session.segments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio Playback")
                            .font(.headline)
                        AudioPlayerView(session: session)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Segments
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio Segments")
                        .font(.headline)
                    if session.segments.isEmpty {
                        ContentUnavailableView(
                            "No Segments",
                            systemImage: "waveform",
                            description: Text("No audio segments found for this session")
                        )
                    } else {
                        ForEach(session.segments.sorted(by: { $0.startTime < $1.startTime })) { segment in
                            SegmentRowView(segment: segment)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
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

struct TranscriptionSummaryView: View {
    let session: RecordingSession
    
    var body: some View {
        let totalSegments = session.segments.count
        let completedTranscriptions = session.segments.filter { $0.transcription?.status == .completed }.count
        let failedTranscriptions = session.segments.filter { $0.transcription?.status == .failed }.count
        let processingTranscriptions = session.segments.filter { $0.transcription?.status == .processing }.count
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcription Summary")
                .font(.headline)
            
            HStack(spacing: 16) {
                TranscriptionStatView(
                    title: "Completed",
                    count: completedTranscriptions,
                    total: totalSegments,
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                TranscriptionStatView(
                    title: "Processing",
                    count: processingTranscriptions,
                    total: totalSegments,
                    color: .orange,
                    icon: "clock.fill"
                )
                
                TranscriptionStatView(
                    title: "Failed",
                    count: failedTranscriptions,
                    total: totalSegments,
                    color: .red,
                    icon: "exclamationmark.circle.fill"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TranscriptionStatView: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Label("\(count)", systemImage: icon)
                .foregroundColor(color)
                .font(.title2)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if total > 0 {
                Text("\(Int((Double(count) / Double(total)) * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SegmentRowView: View {
    let segment: AudioSegment
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Segment header
            HStack {
                VStack(alignment: .leading) {
                    Text("Segment \(formatStartTime(segment.startTime))")
                        .font(.headline)
                    Text(formatDuration(segment.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Transcription status
                TranscriptionStatusView(transcription: segment.transcription)
                
                // Expand/collapse button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            // Transcription content (expandable)
            if isExpanded {
                TranscriptionContentView(transcription: segment.transcription)
            }
        }
        .padding(.vertical, 4)
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

struct TranscriptionStatusView: View {
    let transcription: Transcription?
    
    var body: some View {
        switch transcription?.status {
        case .completed:
            Label("Completed", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .processing:
            Label("Processing", systemImage: "clock.fill")
                .foregroundColor(.orange)
                .font(.caption)
        case .failed:
            Label("Failed", systemImage: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
        case .pending, nil:
            Label("Pending", systemImage: "circle")
                .foregroundColor(.gray)
                .font(.caption)
        }
    }
}

struct TranscriptionContentView: View {
    let transcription: Transcription?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let transcription = transcription {
                switch transcription.status {
                case .completed:
                    if !transcription.text.isEmpty {
                        Text(transcription.text)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else {
                        Text("No transcription text available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                case .processing:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Transcribing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                case .failed:
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transcription Failed")
                            .font(.caption)
                            .foregroundColor(.red)
                        if let error = transcription.error {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemRed).opacity(0.1))
                    .cornerRadius(8)
                case .pending:
                    Text("Waiting to transcribe...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            } else {
                Text("No transcription available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
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