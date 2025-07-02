import Foundation
import SwiftData

@Model
class AudioSegment: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var startTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var fileURL: URL?
    var session: RecordingSession?
    @Relationship(deleteRule: .cascade)
    var transcription: Transcription?
    
    init(startTime: TimeInterval, duration: TimeInterval, fileURL: URL? = nil) {
        self.startTime = startTime
        self.duration = duration
        self.fileURL = fileURL
    }
} 