import SwiftUI
import SwiftData

struct SessionListView: View {
    @Query private var sessions: [RecordingSession]
    @Environment(\.modelContext) private var modelContext
    
    init() {
        let descriptor = FetchDescriptor<RecordingSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        _sessions = Query(descriptor)
    }
    
    var body: some View {
        NavigationView {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Recordings",
                        systemImage: "mic.slash",
                        description: Text("Start recording to see your sessions here")
                    )
                } else {
                    ForEach(sessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            SessionRowView(session: session)
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
            .navigationTitle("Recording Sessions")
            .refreshable {
                // SwiftData automatically updates, but this provides pull-to-refresh UX
            }
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
        try? modelContext.save()
    }
}

struct SessionRowView: View {
    let session: RecordingSession
    @State private var showingAudioPlayer = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(session.date, style: .date)
                        .font(.headline)
                    Text(session.date, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(formatDuration(session.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(session.segments.count) segments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar showing transcription status
            TranscriptionProgressView(session: session)
            
            // Quick audio player
            if !session.segments.isEmpty {
                CompactAudioPlayerView(session: session)
            }
        }
        .padding(.vertical, 4)
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

struct TranscriptionProgressView: View {
    let session: RecordingSession
    
    var body: some View {
        let totalSegments = session.segments.count
        let completedTranscriptions = session.segments.filter { $0.transcription?.status == .completed }.count
        let failedTranscriptions = session.segments.filter { $0.transcription?.status == .failed }.count
        let processingTranscriptions = session.segments.filter { $0.transcription?.status == .processing }.count
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Transcription Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(completedTranscriptions)/\(totalSegments)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if totalSegments > 0 {
                ProgressView(value: Double(completedTranscriptions), total: Double(totalSegments))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                
                HStack(spacing: 12) {
                    if completedTranscriptions > 0 {
                        Label("\(completedTranscriptions)", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                    }
                    if processingTranscriptions > 0 {
                        Label("\(processingTranscriptions)", systemImage: "clock.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                    }
                    if failedTranscriptions > 0 {
                        Label("\(failedTranscriptions)", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

#Preview {
    SessionListView()
        .modelContainer(for: RecordingSession.self, inMemory: true)
} 