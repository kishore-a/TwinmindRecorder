import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordingSession.date, order: .reverse) private var sessions: [RecordingSession]
    @State private var renamingSession: RecordingSession? = nil
    @State private var newSessionName: String = ""
    @State private var showRenameAlert = false
    @State private var searchText: String = ""
    @State private var minSegments: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    TextField("Search sessions", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.tertiaryBackground)
                .cornerRadius(10)
                .padding([.horizontal, .top], DesignSystem.Spacing.lg)
                HStack {
                    Text("Min Segments: ")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Stepper(value: $minSegments, in: 0...20) {
                        Text("\(minSegments)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        if filteredAndGroupedSessions.isEmpty {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                Image(systemName: "mic.slash")
                                    .font(.system(size: 60))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                
                                VStack(spacing: DesignSystem.Spacing.sm) {
                                    Text("No Recordings")
                                        .font(DesignSystem.Typography.title2)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                    Text("Start recording to see your sessions here")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(DesignSystem.Spacing.xxl)
                        } else {
                            ForEach(filteredAndGroupedSessions.keys.sorted(by: >), id: \.self) { group in
                                Section(header: Text(group)
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ) {
                                    ForEach(filteredAndGroupedSessions[group] ?? []) { session in
                                        NavigationLink(destination: SessionDetailView(session: session)) {
                                            SessionRowView(session: session)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button("Rename") {
                                                renamingSession = session
                                                newSessionName = session.name
                                                showRenameAlert = true
                                            }
                                            Button(role: .destructive) {
                                                deleteSession(session)
                                            } label: {
                                                Text("Delete")
                                            }
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button("Rename") {
                                                renamingSession = session
                                                newSessionName = session.name
                                                showRenameAlert = true
                                            }.tint(.blue)
                                            Button(role: .destructive) {
                                                deleteSession(session)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
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
            }
            .navigationTitle("Recording Sessions")
            .navigationBarTitleDisplayMode(.large)
            .alert("Rename Session", isPresented: $showRenameAlert, actions: {
                TextField("Session Name", text: $newSessionName)
                Button("Save", action: saveRenamedSession)
                Button("Cancel", role: .cancel) {}
            }, message: {
                Text("Enter a new name for the session.")
            })
            .refreshable {
                try? modelContext.save()
            }
        }
    }
    
    private var filteredAndGroupedSessions: [String: [RecordingSession]] {
        let filtered = sessions.filter { session in
            (searchText.isEmpty || session.name.localizedCaseInsensitiveContains(searchText)) &&
            session.segments.count >= minSegments
        }
        return Dictionary(grouping: filtered, by: { session in
            groupLabel(for: session.date)
        })
    }
    
    private func groupLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), date >= weekAgo {
            return "This Week"
        } else {
            return "Earlier"
        }
    }
    
    private func deleteSession(_ session: RecordingSession) {
        modelContext.delete(session)
        try? modelContext.save()
    }
    
    private func saveRenamedSession() {
        guard let session = renamingSession else { return }
        session.name = newSessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        renamingSession = nil
        newSessionName = ""
    }
}

struct SessionRowView: View {
    let session: RecordingSession
    @State private var showingAudioPlayer = false
    
    var body: some View {
        ModernCard(shadow: DesignSystem.Shadows.small) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Header with session info
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    // Session icon
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primaryGradient)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "waveform")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    // Session details
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(session.name)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(session.date, style: .date)
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(session.date, style: .time)
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Session stats
                    VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                        Text(formatDuration(session.duration))
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.primary)
                        
                        Text("\(session.segments.count) segments")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                // Progress bar showing transcription status
                TranscriptionProgressView(session: session)
                
                // Quick audio player
                if !session.segments.isEmpty {
                    CompactAudioPlayerView(session: session)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
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
        
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Transcription Progress")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
                Text("\(completedTranscriptions)/\(totalSegments)")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            if totalSegments > 0 {
                ProgressView(value: Double(completedTranscriptions), total: Double(totalSegments))
                    .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.primary))
                    .scaleEffect(y: 1.5)
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    if completedTranscriptions > 0 {
                        StatusBadge(
                            text: "\(completedTranscriptions)",
                            color: DesignSystem.Colors.success,
                            icon: "checkmark.circle.fill"
                        )
                    }
                    if processingTranscriptions > 0 {
                        StatusBadge(
                            text: "\(processingTranscriptions)",
                            color: DesignSystem.Colors.warning,
                            icon: "clock.fill"
                        )
                    }
                    if failedTranscriptions > 0 {
                        StatusBadge(
                            text: "\(failedTranscriptions)",
                            color: DesignSystem.Colors.error,
                            icon: "exclamationmark.circle.fill"
                        )
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